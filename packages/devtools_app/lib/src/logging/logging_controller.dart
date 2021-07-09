// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../config_specific/logger/logger.dart' as logger;
import '../core/message_bus.dart';
import '../globals.dart';
import '../inspector/diagnostics_node.dart';
import '../inspector/inspector_service.dart';
import '../inspector/inspector_tree.dart';
import '../ui/filter.dart';
import '../ui/search.dart';
import '../utils.dart';
import '../vm_service_wrapper.dart';
import 'logging_screen.dart';

// For performance reasons, we drop old logs in batches, so the log will grow
// to kMaxLogItemsUpperBound then truncate to kMaxLogItemsLowerBound.
const int kMaxLogItemsLowerBound = 5000;
const int kMaxLogItemsUpperBound = 5500;
final DateFormat timeFormat = DateFormat('HH:mm:ss.SSS');

bool _verboseDebugging = false;

typedef OnShowDetails = void Function({
  String text,
  InspectorTreeController tree,
});

typedef CreateLoggingTree = InspectorTreeController Function({
  VoidCallback onSelectionChange,
});

Future<String> _retrieveFullStringValue(
  VmServiceWrapper service,
  IsolateRef isolateRef,
  InstanceRef stringRef,
) {
  final fallback = '${stringRef.valueAsString}...';
  // TODO(kenz): why is service null?
  return service?.retrieveFullStringValue(
        isolateRef.id,
        stringRef,
        onUnavailable: (truncatedValue) => fallback,
      ) ??
      fallback;
}

class LoggingDetailsController {
  LoggingDetailsController({
    @required this.onShowInspector,
    @required this.onShowDetails,
    @required this.createLoggingTree,
  });

  static const JsonEncoder jsonEncoder = JsonEncoder.withIndent('  ');

  LogData data;

  /// Callback to execute to show the inspector.
  final VoidCallback onShowInspector;

  /// Callback to execute to show the data from the details tree in the view.
  final OnShowDetails onShowDetails;

  /// Callback to create an inspectorTree for the logging view of the correct
  /// type.
  final CreateLoggingTree createLoggingTree;

  InspectorTreeController tree;

  void setData(LogData data) {
    this.data = data;

    tree = null;

    if (data == null) {
      onShowDetails(text: '');
      return;
    }

    if (data.node != null) {
      tree = createLoggingTree(
        onSelectionChange: () {
          final InspectorTreeNode node = tree.selection;
          if (node != null) {
            tree.maybePopulateChildren(node);
          }

          // TODO(jacobr): node.diagnostic.isDiagnosticableValue isn't quite
          // right.
          if (node.diagnostic.isDiagnosticableValue) {
            // TODO(jacobr): warn if the selection can't be set as the node is
            // stale which is likely if this is an old log entry.
            if (onShowInspector != null) {
              onShowInspector();
            }
            node.diagnostic.setSelectionInspector(false);
          }
        },
      );

      final InspectorTreeNode root = tree.setupInspectorTreeNode(
        tree.createNode(),
        data.node,
        expandChildren: true,
        expandProperties: true,
      );
      // No sense in collapsing the root node.
      root.allowExpandCollapse = false;
      tree.root = root;
      onShowDetails(tree: tree);

      return;
    }

    // See if we need to asynchronously compute the log entry details.
    if (data.needsComputing) {
      onShowDetails(text: '');

      data.compute().then((_) {
        // If we're still displaying the same log entry, then update the UI with
        // the calculated value.
        if (this.data == data) {
          _updateUIFromData();
        }
      });
    } else {
      _updateUIFromData();
    }
  }

  void _updateUIFromData() {
    if (data.details.startsWith('{') && data.details.endsWith('}')) {
      try {
        // If the string decodes properly, then format the json.
        final dynamic result = jsonDecode(data.details);
        onShowDetails(text: jsonEncoder.convert(result));
      } catch (e) {
        onShowDetails(text: data.details);
      }
    } else {
      onShowDetails(text: data.details);
    }
  }
}

class LoggingController extends DisposableController
    with
        SearchControllerMixin<LogData>,
        FilterControllerMixin<LogData>,
        AutoDisposeControllerMixin {
  LoggingController() {
    autoDispose(
        serviceManager.onConnectionAvailable.listen(_handleConnectionStart));
    if (serviceManager.connectedAppInitialized) {
      _handleConnectionStart(serviceManager.service);
    }
    autoDispose(
        serviceManager.onConnectionClosed.listen(_handleConnectionStop));
    _handleBusEvents();
  }

  static const kindFilterId = 'logging-kind-filter';

  final _filterArgs = {
    kindFilterId: FilterArgument(keys: ['kind', 'k']),
  };

  @override
  Map<String, FilterArgument> get filterArgs => _filterArgs;

  final StreamController<String> _logStatusController =
      StreamController.broadcast();

  /// A stream of events for the textual description of the log contents.
  ///
  /// See also [statusText].
  Stream get onLogStatusChanged => _logStatusController.stream;

  List<LogData> data = <LogData>[];

  final _selectedLog = ValueNotifier<LogData>(null);

  ValueListenable<LogData> get selectedLog => _selectedLog;

  void selectLog(LogData data) {
    _selectedLog.value = data;
  }

  void _updateData(List<LogData> logs) {
    data = logs;
    filterData(activeFilter.value);
    refreshSearchMatches();
    _updateSelection();
    _updateStatus();
  }

  void _updateSelection() {
    final selected = _selectedLog.value;
    if (selected != null) {
      final logs = filteredData.value;
      if (!logs.contains(selected)) {
        _selectedLog.value = null;
      }
    }
  }

  ObjectGroup get objectGroup => serviceManager.consoleService.objectGroup;

  String get statusText {
    final int totalCount = data.length;
    final int showingCount = filteredData.value.length;

    String label;

    if (totalCount == showingCount) {
      label = nf.format(totalCount);
    } else {
      label = 'showing ${nf.format(showingCount)} of '
          '${nf.format(totalCount)}';
    }

    label = '$label ${pluralize('event', totalCount)}';

    return label;
  }

  void _updateStatus() {
    final label = statusText;
    _logStatusController.add(label);
  }

  void clear() {
    resetFilter();
    _updateData([]);
    serviceManager.errorBadgeManager.clearErrors(LoggingScreen.id);
  }

  void _handleConnectionStart(VmServiceWrapper service) async {
    // Log stdout events.
    final _StdoutEventHandler stdoutHandler =
        _StdoutEventHandler(this, 'stdout');
    autoDispose(service.onStdoutEventWithHistory.listen(stdoutHandler.handle));

    // Log stderr events.
    final _StdoutEventHandler stderrHandler =
        _StdoutEventHandler(this, 'stderr', isError: true);
    autoDispose(service.onStderrEventWithHistory.listen(stderrHandler.handle));

    // Log GC events.
    autoDispose(service.onGCEvent.listen(_handleGCEvent));

    // Log `dart:developer` `log` events.
    autoDispose(
        service.onLoggingEventWithHistory.listen(_handleDeveloperLogEvent));

    // Log Flutter extension events.
    autoDispose(
        service.onExtensionEventWithHistory.listen(_handleExtensionEvent));
  }

  void _handleExtensionEvent(Event e) async {
    // Events to show without a summary in the table.
    const Set<String> untitledEvents = {
      'Flutter.FirstFrame',
      'Flutter.FrameworkInitialization',
    };

    // TODO(jacobr): make the list of filtered events configurable.
    const Set<String> filteredEvents = {
      // Suppress these events by default as they just add noise to the log
      ServiceExtensionStateChangedInfo.eventName,
    };

    if (filteredEvents.contains(e.extensionKind)) {
      return;
    }

    if (e.extensionKind == FrameInfo.eventName) {
      final FrameInfo frame = FrameInfo.from(e.extensionData.data);

      final String frameId = '#${frame.number}';
      final String frameInfoText =
          '$frameId ${frame.elapsedMs.toStringAsFixed(1).padLeft(4)}ms ';

      log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.extensionData.data),
        e.timestamp,
        summary: frameInfoText,
      ));
    } else if (e.extensionKind == ImageSizesForFrame.eventName) {
      final images = ImageSizesForFrame.from(e.extensionData.data);

      for (final image in images) {
        log(LogData(
          e.extensionKind.toLowerCase(),
          jsonEncode(image.rawJson),
          e.timestamp,
          summary: image.summary,
        ));
      }
    } else if (e.extensionKind == NavigationInfo.eventName) {
      final NavigationInfo navInfo = NavigationInfo.from(e.extensionData.data);

      log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.json),
        e.timestamp,
        summary: navInfo.routeDescription,
      ));
    } else if (untitledEvents.contains(e.extensionKind)) {
      log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.json),
        e.timestamp,
        summary: '',
      ));
    } else if (e.extensionKind == ServiceExtensionStateChangedInfo.eventName) {
      final ServiceExtensionStateChangedInfo changedInfo =
          ServiceExtensionStateChangedInfo.from(e.extensionData.data);

      log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.json),
        e.timestamp,
        summary: '${changedInfo.extension}: ${changedInfo.value}',
      ));
    } else if (e.extensionKind == 'Flutter.Error') {
      // TODO(pq): add tests for error extension handling once framework changes
      // are landed.
      final RemoteDiagnosticsNode node =
          RemoteDiagnosticsNode(e.extensionData.data, objectGroup, false, null);
      // Workaround the fact that the error objects from the server don't have
      // style error.
      node.style = DiagnosticsTreeStyle.error;
      if (_verboseDebugging) {
        logger.log('node toStringDeep:######\n${node.toStringDeep()}\n###');
      }

      final RemoteDiagnosticsNode summary = _findFirstSummary(node) ?? node;
      log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.extensionData.data),
        e.timestamp,
        summary: summary.toDiagnosticsNode().toString(),
      ));
    } else {
      log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.json),
        e.timestamp,
        summary: e.json.toString(),
      ));
    }
  }

  void _handleGCEvent(Event e) {
    final HeapSpace newSpace = HeapSpace.parse(e.json['new']);
    final HeapSpace oldSpace = HeapSpace.parse(e.json['old']);
    final Map<dynamic, dynamic> isolateRef = e.json['isolate'];

    final int usedBytes = newSpace.used + oldSpace.used;
    final int capacityBytes = newSpace.capacity + oldSpace.capacity;

    final int time = ((newSpace.time + oldSpace.time) * 1000).round();

    final String summary = '${isolateRef['name']} • '
        '${e.json['reason']} collection in $time ms • '
        '${printMB(usedBytes, includeUnit: true)} used of ${printMB(capacityBytes, includeUnit: true)}';

    final Map<String, dynamic> event = <String, dynamic>{
      'reason': e.json['reason'],
      'new': newSpace.json,
      'old': oldSpace.json,
      'isolate': isolateRef,
    };

    final String message = jsonEncode(event);
    log(LogData('gc', message, e.timestamp, summary: summary));
  }

  void _handleDeveloperLogEvent(Event e) {
    final VmServiceWrapper service = serviceManager.service;

    final dynamic logRecord = e.json['logRecord'];

    String loggerName =
        _valueAsString(InstanceRef.parse(logRecord['loggerName']));
    if (loggerName == null || loggerName.isEmpty) {
      loggerName = 'log';
    }
    final int level = logRecord['level'];
    final InstanceRef messageRef = InstanceRef.parse(logRecord['message']);
    String summary = _valueAsString(messageRef);
    if (messageRef.valueAsStringIsTruncated == true) {
      summary += '...';
    }
    final InstanceRef error = InstanceRef.parse(logRecord['error']);
    final InstanceRef stackTrace = InstanceRef.parse(logRecord['stackTrace']);

    final String details = summary;
    Future<String> Function() detailsComputer;

    // If the message string was truncated by the VM, or the error object or
    // stackTrace objects were non-null, we need to ask the VM for more
    // information in order to render the log entry. We do this asynchronously
    // on-demand using the `detailsComputer` Future.
    if (messageRef.valueAsStringIsTruncated == true ||
        _isNotNull(error) ||
        _isNotNull(stackTrace)) {
      detailsComputer = () async {
        // Get the full string value of the message.
        String result =
            await _retrieveFullStringValue(service, e.isolate, messageRef);

        // Get information about the error object. Some users of the
        // dart:developer log call may pass a data payload in the `error`
        // field, encoded as a json encoded string, so handle that case.
        if (_isNotNull(error)) {
          if (error.valueAsString != null) {
            final String errorString =
                await _retrieveFullStringValue(service, e.isolate, error);
            result += '\n\n$errorString';
          } else {
            // Call `toString()` on the error object and display that.
            final dynamic toStringResult = await service.invoke(
              e.isolate.id,
              error.id,
              'toString',
              <String>[],
              disableBreakpoints: true,
            );

            if (toStringResult is ErrorRef) {
              final String errorString = _valueAsString(error);
              result += '\n\n$errorString';
            } else if (toStringResult is InstanceRef) {
              final String str = await _retrieveFullStringValue(
                  service, e.isolate, toStringResult);
              result += '\n\n$str';
            }
          }
        }

        // Get info about the stackTrace object.
        if (_isNotNull(stackTrace)) {
          result += '\n\n${_valueAsString(stackTrace)}';
        }

        return result;
      };
    }

    const int severeIssue = 1000;
    final bool isError = level != null && level >= severeIssue ? true : false;

    log(LogData(
      loggerName,
      details,
      e.timestamp,
      isError: isError,
      summary: summary,
      detailsComputer: detailsComputer,
    ));
  }

  void _handleConnectionStop(dynamic event) {}

  void log(LogData log) {
    List<LogData> currentLogs = List.from(data);

    // Insert the new item and clamped the list to kMaxLogItemsLength.
    currentLogs.add(log);

    // Note: We need to drop rows from the start because we want to drop old
    // rows but because that's expensive, we only do it periodically (eg. when
    // the list is 500 rows more).
    if (currentLogs.length > kMaxLogItemsUpperBound) {
      int itemsToRemove = currentLogs.length - kMaxLogItemsLowerBound;
      // Ensure we remove an even number of rows to keep the alternating
      // background in-sync.
      if (itemsToRemove % 2 == 1) {
        itemsToRemove--;
      }
      currentLogs = currentLogs.sublist(itemsToRemove);
    }

    _updateData(currentLogs);
  }

  static RemoteDiagnosticsNode _findFirstSummary(RemoteDiagnosticsNode node) {
    if (node.level == DiagnosticLevel.summary) {
      return node;
    }
    RemoteDiagnosticsNode summary;
    if (node.inlineProperties != null) {
      for (RemoteDiagnosticsNode property in node.inlineProperties) {
        summary = _findFirstSummary(property);
        if (summary != null) return summary;
      }
    }
    if (node.childrenNow != null) {
      for (RemoteDiagnosticsNode child in node.childrenNow) {
        summary = _findFirstSummary(child);
        if (summary != null) return summary;
      }
    }
    return null;
  }

  void _handleBusEvents() {
    // TODO(jacobr): expose the messageBus for use by vm tests.
    if (messageBus != null) {
      autoDispose(
          messageBus.onEvent(type: 'reload.end').listen((BusEvent event) {
        log(
          LogData(
            'hot.reload',
            event.data,
            DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }));

      autoDispose(
          messageBus.onEvent(type: 'restart.end').listen((BusEvent event) {
        log(
          LogData(
            'hot.restart',
            event.data,
            DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }));

      // Listen for debugger events.
      autoDispose(messageBus
          .onEvent()
          .where((event) =>
              event.type == 'debugger' || event.type.startsWith('debugger.'))
          .listen(_handleDebuggerEvent));

      // Listen for DevTools internal events.
      autoDispose(messageBus
          .onEvent()
          .where((event) => event.type.startsWith('devtools.'))
          .listen(_handleDevToolsEvent));
    }
  }

  void _handleDebuggerEvent(BusEvent event) {
    final Event debuggerEvent = event.data;

    // Filter ServiceExtensionAdded events as they're pretty noisy.
    if (debuggerEvent.kind == EventKind.kServiceExtensionAdded) {
      return;
    }

    log(
      LogData(
        event.type,
        jsonEncode(debuggerEvent.json),
        debuggerEvent.timestamp,
        summary: '${debuggerEvent.kind} ${debuggerEvent.isolate.id}',
      ),
    );
  }

  void _handleDevToolsEvent(BusEvent event) {
    var details = event.data.toString();
    String summary;

    if (details.contains('\n')) {
      final lines = details.split('\n');
      summary = lines.first;
      details = lines.sublist(1).join('\n');
    }

    log(
      LogData(
        event.type,
        details,
        DateTime.now().millisecondsSinceEpoch,
        summary: summary,
      ),
    );
  }

  @override
  List<LogData> matchesForSearch(String search) {
    if (search == null || search.isEmpty) return [];
    final matches = <LogData>[];
    final caseInsensitiveSearch = search.toLowerCase();

    final currentLogs = filteredData.value;
    for (final log in currentLogs) {
      if ((log.summary != null &&
              log.summary.toLowerCase().contains(caseInsensitiveSearch)) ||
          (log.details != null &&
              log.details.toLowerCase().contains(caseInsensitiveSearch))) {
        matches.add(log);
        // TODO(kenz): use the value of this property in the logs table to
        // improve performance. This will require some refactoring of FlatTable.
        log.isSearchMatch = true;
      } else {
        log.isSearchMatch = false;
      }
    }
    return matches;
  }

  @override
  void filterData(QueryFilter filter) {
    if (filter == null) {
      filteredData
        ..clear()
        ..addAll(data);
    } else {
      filteredData
        ..clear()
        ..addAll(data.where((log) {
          final kindArg = filter.filterArguments[kindFilterId];
          if (kindArg != null &&
              !kindArg.matchesValue(log.kind.toLowerCase())) {
            return false;
          }

          if (filter.substrings.isNotEmpty) {
            for (final substring in filter.substrings) {
              final caseInsensitiveSubstring = substring.toLowerCase();
              final matchesKind = log.kind != null &&
                  log.kind.toLowerCase().contains(caseInsensitiveSubstring);
              if (matchesKind) return true;

              final matchesSummary = log.summary != null &&
                  log.summary.toLowerCase().contains(caseInsensitiveSubstring);
              if (matchesSummary) return true;

              final matchesDetails = log.details != null &&
                  log.summary.toLowerCase().contains(caseInsensitiveSubstring);
              if (matchesDetails) return true;
            }
            return false;
          }
          return true;
        }).toList());
    }
    activeFilter.value = filter;
  }
}

/// Receive and log stdout / stderr events from the VM.
///
/// This class buffers the events for up to 1ms. This is in order to combine a
/// stdout message and its newline. Currently, `foo\n` is sent as two VM events;
/// we wait for up to 1ms when we get the `foo` event, to see if the next event
/// is a single newline. If so, we add the newline to the previous log message.
class _StdoutEventHandler {
  _StdoutEventHandler(this.loggingController, this.name,
      {this.isError = false});

  final LoggingController loggingController;
  final String name;
  final bool isError;

  LogData buffer;
  Timer timer;

  void handle(Event e) {
    final String message = decodeBase64(e.bytes);

    if (buffer != null) {
      timer?.cancel();

      if (message == '\n') {
        loggingController.log(LogData(
          buffer.kind,
          buffer.details + message,
          buffer.timestamp,
          summary: buffer.summary + message,
          isError: buffer.isError,
        ));
        buffer = null;
        return;
      }

      loggingController.log(buffer);
      buffer = null;
    }

    const maxLength = 200;

    String summary = message;
    if (message.length > maxLength) {
      summary = message.substring(0, maxLength);
    }

    final LogData data = LogData(
      name,
      message,
      e.timestamp,
      summary: summary,
      isError: isError,
    );

    if (message == '\n') {
      loggingController.log(data);
    } else {
      buffer = data;
      timer = Timer(const Duration(milliseconds: 1), () {
        loggingController.log(buffer);
        buffer = null;
      });
    }
  }
}

bool _isNotNull(InstanceRef serviceRef) {
  return serviceRef != null && serviceRef.kind != 'Null';
}

String _valueAsString(InstanceRef ref) {
  if (ref == null) {
    return null;
  }

  if (ref.valueAsString == null) {
    return ref.valueAsString;
  }

  if (ref.valueAsStringIsTruncated == true) {
    return '${ref.valueAsString}...';
  } else {
    return ref.valueAsString;
  }
}

/// A log data object that includes optional summary information about whether
/// the log entry represents an error entry, the log entry kind, and more
/// detailed data for the entry.
///
/// The details can optionally be loaded lazily on first use. If this is the
/// case, this log entry will have a non-null `detailsComputer` field. After the
/// data is calculated, the log entry will be modified to contain the calculated
/// `details` data.
class LogData with DataSearchStateMixin {
  LogData(
    this.kind,
    this._details,
    this.timestamp, {
    this.summary,
    this.isError = false,
    this.detailsComputer,
    this.node,
  });

  final String kind;
  final int timestamp;
  final bool isError;
  final String summary;

  final RemoteDiagnosticsNode node;
  String _details;
  Future<String> Function() detailsComputer;

  static const JsonEncoder prettyPrinter = JsonEncoder.withIndent('  ');

  String get details => _details;

  bool get needsComputing => detailsComputer != null;

  Future<void> compute() async {
    _details = await detailsComputer();
    detailsComputer = null;
  }

  String get prettyPrinted {
    if (needsComputing) {
      return details;
    }

    try {
      return prettyPrinter.convert(jsonDecode(details)).replaceAll(r'\n', '\n');
    } catch (_) {
      return details;
    }
  }

  bool matchesFilter(String filter) {
    if (kind.toLowerCase().contains(filter)) {
      return true;
    }

    if (summary != null && summary.toLowerCase().contains(filter)) {
      return true;
    }

    if (_details != null && _details.toLowerCase().contains(filter)) {
      return true;
    }

    return false;
  }

  @override
  String toString() => 'LogData($kind, $timestamp)';
}

class FrameInfo {
  FrameInfo(this.number, this.elapsedMs, this.startTimeMs);

  static const String eventName = 'Flutter.Frame';

  static const double kTargetMaxFrameTimeMs = 1000.0 / 60;

  static FrameInfo from(Map<String, dynamic> data) {
    return FrameInfo(
        data['number'], data['elapsed'] / 1000, data['startTime'] / 1000);
  }

  final int number;
  final num elapsedMs;
  final num startTimeMs;

  @override
  String toString() => 'frame $number ${elapsedMs.toStringAsFixed(1)}ms';
}

class ImageSizesForFrame {
  ImageSizesForFrame(
    this.source,
    this.displaySize,
    this.imageSize,
    this.rawJson,
  );

  static const String eventName = 'Flutter.ImageSizesForFrame';

  static List<ImageSizesForFrame> from(Map<String, dynamic> data) {
    //     "packages/flutter_gallery_assets/assets/icons/material/2.0x/material.png": {
    //       "source": "packages/flutter_gallery_assets/assets/icons/material/2.0x/material.png",
    //       "displaySize": {
    //         "width": 64.0,
    //         "height": 63.99999999999999
    //       },
    //       "imageSize": {
    //         "width": 128.0,
    //         "height": 128.0
    //       },
    //       "displaySizeInBytes": 21845,
    //       "decodedSizeInBytes": 87381
    //     }

    return data.values.map((entry) {
      return ImageSizesForFrame(
        entry['source'],
        entry['displaySize'],
        entry['imageSize'],
        entry,
      );
    }).toList();
  }

  final String source;
  final Map<String, Object> displaySize;
  final Map<String, Object> imageSize;
  final Map<String, Object> rawJson;

  String get summary {
    final file = path.basename(source);

    final int displaySizeInBytes = rawJson['displaySizeInBytes'];
    final int decodedSizeInBytes = rawJson['decodedSizeInBytes'];

    final double expansion =
        math.sqrt(decodedSizeInBytes ?? 0) / math.sqrt(displaySizeInBytes ?? 1);

    return 'Image $file • displayed at '
        '${_round(displaySize['width'])}x${_round(displaySize['height'])}'
        ' • created at '
        '${_round(imageSize['width'])}x${_round(imageSize['height'])}'
        ' • ${expansion.toStringAsFixed(1)}x';
  }

  int _round(num value) => value.round();

  @override
  String toString() =>
      '$source ${displaySize['width']}x${displaySize['height']}';
}

class NavigationInfo {
  NavigationInfo(this._route);

  static const String eventName = 'Flutter.Navigation';

  static NavigationInfo from(Map<String, dynamic> data) {
    return NavigationInfo(data['route']);
  }

  final Map<String, dynamic> _route;

  String get routeDescription => _route == null ? null : _route['description'];
}

class ServiceExtensionStateChangedInfo {
  ServiceExtensionStateChangedInfo(this.extension, this.value);

  static const String eventName = 'Flutter.ServiceExtensionStateChanged';

  static ServiceExtensionStateChangedInfo from(Map<String, dynamic> data) {
    return ServiceExtensionStateChangedInfo(data['extension'], data['value']);
  }

  final String extension;
  final dynamic value;
}

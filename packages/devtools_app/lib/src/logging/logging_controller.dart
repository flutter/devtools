// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger.dart';
import '../core/message_bus.dart';
import '../globals.dart';
import '../inspector/diagnostics_node.dart';
import '../inspector/inspector_service.dart';
import '../inspector/inspector_tree.dart';
import '../memory/heap_space.dart';
import '../table_data.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../utils.dart';
import '../vm_service_wrapper.dart';

// For performance reasons, we drop old logs in batches, so the log will grow
// to kMaxLogItemsUpperBound then truncate to kMaxLogItemsLowerBound.
const int kMaxLogItemsLowerBound = 5000;
const int kMaxLogItemsUpperBound = 5500;
final DateFormat timeFormat = DateFormat('HH:mm:ss.SSS');

bool _verboseDebugging = false;

typedef OnLogCountStatusChanged = void Function(String status);

typedef OnShowDetails = void Function({
  String text,
  InspectorTreeController tree,
});

typedef CreateLoggingTree = InspectorTreeController Function({
  VoidCallback onSelectionChange,
});

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

  /// Callback to executue to show the data from the details tree in the view.
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
      assert(data.node == null);
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
    assert(data.node == null);
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

class LoggingController {
  LoggingController({
    @required this.onLogCountStatusChanged,
    @required this.isVisible,
  }) {
    _listen(serviceManager.onConnectionAvailable, _handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    _listen(serviceManager.onConnectionClosed, _handleConnectionStop);
  }

  LoggingDetailsController detailsController;

  /// Listen on a stream and track the stream subscription for automatic
  /// disposal if the dispose method is called.
  StreamSubscription<T> _listen<T>(Stream<T> stream, void onData(T event)) {
    final subscription = stream.listen(onData);
    _subscriptions.add(subscription);
    return subscription;
  }

  TableData<LogData> get loggingTableModel => _loggingTableModel;
  TableData<LogData> _loggingTableModel;

  set loggingTableModel(TableData<LogData> model) {
    _loggingTableModel = model;
    _listen(_loggingTableModel.onSelect, (LogData selection) {
      detailsController?.setData(selection);
    });

    _updateStatus();
    _listen(_loggingTableModel.onRowsChanged, (_) {
      _updateStatus();
    });

    // TODO(jacobr): expose the messageBus for use by vm tests.
    if (messageBus != null) {
      _listen(messageBus.onEvent(type: 'reload.end'), (BusEvent event) {
        _log(LogData(
          'hot.reload',
          event.data,
          DateTime.now().millisecondsSinceEpoch,
        ));
      });
      _listen(messageBus.onEvent(type: 'restart.end'), (BusEvent event) {
        _log(LogData(
          'hot.restart',
          event.data,
          DateTime.now().millisecondsSinceEpoch,
        ));
      });
    }
  }

  /// Callbacks to apply changes in the controller to other views.
  final OnLogCountStatusChanged onLogCountStatusChanged;

  /// Callback returning whether the logging screen is visible.
  final bool Function() isVisible;

  List<LogData> data = <LogData>[];

  final List<StreamSubscription> _subscriptions = [];

  DateTime _lastScrollTime;

  bool _hasPendingUiUpdates = false;

  final Notifier onLogsUpdated = Notifier();

  /// ObjectGroup for Flutter (completes with null for non-Flutter apps).
  Future<ObjectGroup> objectGroup;

  void _updateStatus() {
    final int count = _loggingTableModel.rowCount;
    final String label = count >= kMaxLogItemsLowerBound
        ? '${nf.format(kMaxLogItemsLowerBound)}+'
        : nf.format(count);
    onLogCountStatusChanged('$label events');
  }

  void clear() {
    data.clear();
    detailsController?.setData(null);
    _loggingTableModel?.setRows(data);
  }

  void _handleConnectionStart(VmServiceWrapper service) async {
    // Log stdout events.
    final _StdoutEventHandler stdoutHandler =
        _StdoutEventHandler(this, 'stdout');
    _listen(service.onStdoutEvent, stdoutHandler.handle);

    // Log stderr events.
    final _StdoutEventHandler stderrHandler =
        _StdoutEventHandler(this, 'stderr', isError: true);
    _listen(service.onStderrEvent, stderrHandler.handle);

    // Log GC events.
    _listen(service.onGCEvent, _handleGCEvent);

    // Log `dart:developer` `log` events.
    _listen(service.onLoggingEvent, _handleDeveloperLogEvent);

    // Log Flutter extension events.
    _listen(service.onExtensionEvent, _handleExtensionEvent);

    await ensureInspectorServiceDependencies();

    objectGroup = InspectorService.createGroup(service, 'console-group')
        .catchError((e) => null,
            test: (e) => e is FlutterInspectorLibraryNotFound);
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
      final String frameInfo =
          '<span class="pre">$frameId ${frame.elapsedMs.toStringAsFixed(1).padLeft(4)}ms </span>';
      final String div = _createFrameDivHtml(frame);

      _log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.extensionData.data),
        e.timestamp,
        summaryHtml: '$frameInfo$div',
      ));
    } else if (e.extensionKind == NavigationInfo.eventName) {
      final NavigationInfo navInfo = NavigationInfo.from(e.extensionData.data);

      _log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.json),
        e.timestamp,
        summary: navInfo.routeDescription,
      ));
    } else if (untitledEvents.contains(e.extensionKind)) {
      _log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.json),
        e.timestamp,
        summary: '',
      ));
    } else if (e.extensionKind == ServiceExtensionStateChangedInfo.eventName) {
      final ServiceExtensionStateChangedInfo changedInfo =
          ServiceExtensionStateChangedInfo.from(e.extensionData.data);

      _log(LogData(
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
        log('node toStringDeep:######\n${node.toStringDeep()}\n###');
      }

      final RemoteDiagnosticsNode summary = _findFirstSummary(node) ?? node;
      _log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.json),
        e.timestamp,
        summary: summary.toDiagnosticsNode().toString(),
        node: node,
      ));
    } else {
      _log(LogData(
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
        '${printMb(usedBytes)} MB used of ${printMb(capacityBytes)} MB';

    final Map<String, dynamic> event = <String, dynamic>{
      'reason': e.json['reason'],
      'new': newSpace.json,
      'old': oldSpace.json,
      'isolate': isolateRef,
    };

    final String message = jsonEncode(event);
    _log(LogData('gc', message, e.timestamp, summary: summary));
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
    Future<String> detailsComputer;

    // If the message string was truncated by the VM, or the error object or
    // stackTrace objects were non-null, we need to ask the VM for more
    // information in order to render the log entry. We do this asynchronously
    // on-demand using the `detailsComputer` Future.
    if (messageRef.valueAsStringIsTruncated == true ||
        _isNotNull(error) ||
        _isNotNull(stackTrace)) {
      detailsComputer = Future<String>(() async {
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
      });
    }

    const int severeIssue = 1000;
    final bool isError = level != null && level >= severeIssue ? true : false;

    _log(LogData(
      loggerName,
      details,
      e.timestamp,
      isError: isError,
      summary: summary,
      detailsComputer: detailsComputer,
    ));
  }

  Future<String> _retrieveFullStringValue(
    VmServiceWrapper service,
    IsolateRef isolateRef,
    InstanceRef stringRef,
  ) async {
    if (stringRef.valueAsStringIsTruncated != true) {
      return stringRef.valueAsString;
    }

    final dynamic result = await service.getObject(isolateRef.id, stringRef.id,
        offset: 0, count: stringRef.length);
    if (result is Instance) {
      final Instance obj = result;
      return obj.valueAsString;
    } else {
      return '${stringRef.valueAsString}...';
    }
  }

  void _handleConnectionStop(dynamic event) {}

  void _log(LogData log) {
    // Insert the new item and clamped the list to kMaxLogItemsLength.
    data.add(log);
    // Note: We need to drop rows from the start because we want to drop old
    // rows but because that's expensive, we only do it periodically (eg. when
    // the list is 500 rows more).
    if (data.length > kMaxLogItemsUpperBound) {
      int itemsToRemove = data.length - kMaxLogItemsLowerBound;
      // Ensure we remove an even number of rows to keep the alternating
      // background in-sync.
      if (itemsToRemove % 2 == 1) {
        itemsToRemove--;
      }
      data = data.sublist(itemsToRemove);
    }

    if (isVisible() && _loggingTableModel != null) {
      // TODO(jacobr): adding data should be more incremental than this.
      // We are blowing away state for all already added rows.
      _loggingTableModel.setRows(data);
      // Smooth scroll if we haven't scrolled in a while, otherwise use an
      // immediate scroll because repeatedly smooth scrolling on the web means
      // you never reach your destination.
      final DateTime now = DateTime.now();
      final bool smoothScroll = _lastScrollTime == null ||
          _lastScrollTime.difference(now).inSeconds > 1;
      _lastScrollTime = now;
      _loggingTableModel.scrollTo(data.last,
          scrollBehavior: smoothScroll ? 'smooth' : 'auto');
    } else {
      _hasPendingUiUpdates = true;
    }
    onLogsUpdated.notify();
  }

  void entering() {
    if (_hasPendingUiUpdates) {
      _loggingTableModel?.setRows(data);
      _loggingTableModel?.scrollTo(data.last, scrollBehavior: 'auto');
      _hasPendingUiUpdates = false;
    }
  }

  RemoteDiagnosticsNode _findFirstSummary(RemoteDiagnosticsNode node) {
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

  void dispose() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
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
        loggingController._log(LogData(
          buffer.kind,
          buffer.details + message,
          buffer.timestamp,
          summary: buffer.summary + message,
          isError: buffer.isError,
        ));
        buffer = null;
        return;
      }

      loggingController._log(buffer);
      buffer = null;
    }

    String summary = message;
    if (message.length > 200) {
      summary = message.substring(0, 200) + '…';
    }

    final LogData data = LogData(
      name,
      message,
      e.timestamp,
      summary: summary,
      isError: isError,
    );

    if (message == '\n') {
      loggingController._log(data);
    } else {
      buffer = data;
      timer = Timer(const Duration(milliseconds: 1), () {
        loggingController._log(buffer);
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

/// A log data object that includes an optional summary (in either text or html
/// form), information about whether the log entry represents an error entry,
/// the log entry kind, and more detailed data for the entry.
///
/// The details can optionally be loaded lazily on first use. If this is the
/// case, this log entry will have a non-null `detailsComputer` field. After the
/// data is calculated, the log entry will be modified to contain the calculated
/// `details` data.
class LogData {
  LogData(
    this.kind,
    this._details,
    this.timestamp, {
    this.summary,
    this.summaryHtml,
    this.isError = false,
    this.detailsComputer,
    this.node,
  });

  final String kind;
  final int timestamp;
  final bool isError;
  final String summary;
  final String summaryHtml;

  final RemoteDiagnosticsNode node;
  String _details;
  Future<String> detailsComputer;

  String get details => _details;

  bool get needsComputing => detailsComputer != null;

  Future<void> compute() async {
    _details = await detailsComputer;
    detailsComputer = null;
  }
}

class LogKindColumn extends ColumnData<LogData> {
  LogKindColumn() : super('Kind');

  @override
  bool get supportsSorting => false;

  @override
  bool get usesHtml => true;

  @override
  String get cssClass => 'log-label-column';

  @override
  dynamic getValue(LogData dataObject) {
    final String cssClass = getCssClassForEventKind(dataObject);

    return '<span class="label $cssClass">${dataObject.kind}</span>';
  }

  @override
  String render(dynamic value) => value;
}

class LogWhenColumn extends ColumnData<LogData> {
  LogWhenColumn() : super('When');

  @override
  String get cssClass => 'pre monospace';

  @override
  bool get supportsSorting => false;

  @override
  dynamic getValue(LogData dataObject) => dataObject.timestamp;

  @override
  String render(dynamic value) {
    return value == null
        ? ''
        : timeFormat.format(DateTime.fromMillisecondsSinceEpoch(value));
  }
}

class LogMessageColumn extends ColumnData<LogData> {
  LogMessageColumn(this._logMessageToHtml) : super.wide('Message');

  final String Function(String) _logMessageToHtml;

  @override
  String get cssClass => 'pre-wrap monospace';

  @override
  bool get usesHtml => true;

  @override
  bool get supportsSorting => false;

  @override
  dynamic getValue(LogData dataObject) => dataObject;

  @override
  String render(dynamic value) {
    final LogData log = value;

    if (log.summaryHtml != null) {
      return log.summaryHtml;
    } else {
      return _logMessageToHtml(log.summary ?? log.details);
    }
  }
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

String getCssClassForEventKind(LogData item) {
  String cssClass = '';

  if (item.kind == 'stderr' || item.isError) {
    cssClass = 'stderr';
  } else if (item.kind == 'stdout') {
    cssClass = 'stdout';
  } else if (item.kind == 'flutter.error') {
    cssClass = 'stderr';
  } else if (item.kind.startsWith('flutter')) {
    cssClass = 'flutter';
  } else if (item.kind == 'gc') {
    cssClass = 'gc';
  }

  return cssClass;
}

String _createFrameDivHtml(FrameInfo frame) {
  const double maxFrameEventBarMs = 100.0;
  final String classes = (frame.elapsedMs >= FrameInfo.kTargetMaxFrameTimeMs)
      ? 'frame-bar over-budget'
      : 'frame-bar';

  final int pixelWidth =
      (math.min(frame.elapsedMs, maxFrameEventBarMs) * 3).round();
  return '<div class="$classes" style="width: ${pixelWidth}px"/>';
}

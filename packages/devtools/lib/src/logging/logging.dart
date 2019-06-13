// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:split/split.dart' as split;
import 'package:vm_service_lib/vm_service_lib.dart';

import '../core/message_bus.dart';
import '../framework/framework.dart';
import '../globals.dart';
import '../inspector/diagnostics_node.dart';
import '../inspector/inspector_service.dart';
import '../inspector/inspector_tree.dart';
import '../inspector/inspector_tree_html.dart';
import '../tables.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../ui/ui_utils.dart';
import '../utils.dart';
import '../vm_service_wrapper.dart';

// For performance reasons, we drop old logs in batches, so the log will grow
// to kMaxLogItemsUpperBound then truncate to kMaxLogItemsLowerBound.
const int kMaxLogItemsLowerBound = 5000;
const int kMaxLogItemsUpperBound = 5500;
final DateFormat timeFormat = DateFormat('HH:mm:ss.SSS');

bool _verboseDebugging = false;

class LoggingScreen extends Screen {
  LoggingScreen()
      : super(name: 'Logging', id: 'logging', iconClass: 'octicon-clippy') {
    logCountStatus = StatusItem();
    logCountStatus.element.text = '';
    addStatusItem(logCountStatus);

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  Table<LogData> loggingTable;

  LogDetailsUI logDetailsUI;

  StatusItem logCountStatus;

  SetStateMixin loggingStateMixin = SetStateMixin();

  bool hasPendingDomUpdates = false;

  /// ObjectGroup for Flutter (completes with null for non-Flutter apps).
  Future<ObjectGroup> objectGroup;

  @override
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    this.framework = framework;

    // TODO(devoncarew): Add checkbox toggles to enable specific logging channels.

    screenDiv.add(<CoreElement>[
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..clazz('align-items-center')
            ..layoutHorizontal()
            ..add(<CoreElement>[
              PButton('Clear logs')
                ..small()
                ..click(_clear),
            ])
        ]),
      div(c: 'section log-area bidirectional')
        ..flex()
        ..add(<CoreElement>[
          _createTableView()
            ..layoutHorizontal()
            ..clazz('section')
            ..clazz('full-size')
            ..flex(),
          logDetailsUI = LogDetailsUI(),
        ]),
    ]);

    // configure the table / details splitter
    split.flexSplitBidirectional(
      [loggingTable.element.element, logDetailsUI.element],
      gutterSize: defaultSplitterWidth,
      horizontalSizes: [60, 40],
      verticalSizes: [70, 30],
    );

    loggingTable.onSelect.listen((LogData selection) {
      logDetailsUI.setData(selection);
    });

    _updateStatus();
    loggingTable.onRowsChanged.listen((_) {
      _updateStatus();
    });

    messageBus.onEvent(type: 'reload.end').listen((BusEvent event) {
      _log(LogData(
        'hot.reload',
        event.data,
        DateTime.now().millisecondsSinceEpoch,
      ));
    });
    messageBus.onEvent(type: 'restart.end').listen((BusEvent event) {
      _log(LogData(
        'hot.restart',
        event.data,
        DateTime.now().millisecondsSinceEpoch,
      ));
    });

    return screenDiv;
  }

  @override
  void entering() {
    if (hasPendingDomUpdates) {
      loggingTable.setRows(data);

      hasPendingDomUpdates = false;
    }
  }

  CoreElement _createTableView() {
    loggingTable = Table<LogData>.virtual();

    loggingTable.addColumn(LogWhenColumn());
    loggingTable.addColumn(LogKindColumn());
    loggingTable.addColumn(LogMessageColumn());

    loggingTable.setRows(data);

    return loggingTable.element;
  }

  void _updateStatus() {
    final int count = loggingTable.rowCount;
    final String label = count >= kMaxLogItemsLowerBound
        ? '${nf.format(kMaxLogItemsLowerBound)}+'
        : nf.format(count);
    logCountStatus.element.text = '$label events';
  }

  void _clear() {
    ga.select(ga.logging, ga.clearLogs);
    data.clear();
    logDetailsUI?.setData(null);
    loggingTable.setRows(data);
  }

  void _handleConnectionStart(VmServiceWrapper service) async {
    // Log stdout events.
    final _StdoutEventHandler stdoutHandler =
        _StdoutEventHandler(this, 'stdout');
    service.onStdoutEvent.listen(stdoutHandler.handle);

    // Log stderr events.
    final _StdoutEventHandler stderrHandler =
        _StdoutEventHandler(this, 'stderr', isError: true);
    service.onStderrEvent.listen(stderrHandler.handle);

    // Log GC events.
    service.onGCEvent.listen(_handleGCEvent);

    // Log `dart:developer` `log` events.
    // TODO(devoncarew): Remove `_Logging` support on or after approx. Oct 1 2019.
    service.onEvent('_Logging').listen(_handleDeveloperLogEvent);
    service.onLoggingEvent.listen(_handleDeveloperLogEvent);

    // Log Flutter extension events.
    service.onExtensionEvent.listen(_handleExtensionEvent);

    await ensureInspectorServiceDependencies();

    objectGroup = InspectorService.createGroup(service, 'console-group')
        .catchError((e) => null,
            test: (e) => e is FlutterInspectorLibraryNotFound);
  }

  void _handleExtensionEvent(Event e) async {
    if (e.extensionKind == 'Flutter.Frame') {
      final FrameInfo frame = FrameInfo.from(e.extensionData.data);

      final String frameId = '#${frame.number}';
      final String frameInfo =
          '<span class="pre">$frameId ${frame.elapsedMs.toStringAsFixed(1).padLeft(4)}ms </span>';
      final String div = createFrameDivHtml(frame);

      _log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.extensionData.data),
        e.timestamp,
        summaryHtml: '$frameInfo$div',
      ));
      // todo (pq): add tests for error extension handling once framework changes are landed.
    } else if (e.extensionKind == 'Flutter.Error') {
      final RemoteDiagnosticsNode node =
          RemoteDiagnosticsNode(e.extensionData.data, objectGroup, false, null);
      if (_verboseDebugging) {
        print('node toStringDeep:######\n${node.toStringDeep()}\n###');
      }

      _log(LogData(
        e.extensionKind.toLowerCase(),
        jsonEncode(e.json),
        e.timestamp,
        summary: node.toDiagnosticsNode().toString(),
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

  List<LogData> data = <LogData>[];

  DateTime _lastScrollTime;

  void _log(LogData log) {
    // Insert the new item and clamped the list to kMaxLogItemsLength. The table
    // is rendered reversed so new items are at the top but we can use .add()
    // here which is much faster than inserting at the start of the list.
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

    if (visible && loggingTable != null) {
      // TODO(jacobr): adding data should be more incremental than this.
      // We are blowing away state for all already added rows.
      loggingTable.setRows(data);
      // Smooth scroll if we havent scrolled in a while, otherwise use an
      // immediate scroll because repeatedly smooth scrolling on the web means
      // you never reach your destination.
      final DateTime now = DateTime.now();
      final bool smoothScroll = _lastScrollTime == null ||
          _lastScrollTime.difference(now).inSeconds > 1;
      _lastScrollTime = now;
      loggingTable.scrollTo(data.last,
          scrollBehavior: smoothScroll ? 'smooth' : 'auto');
    } else {
      hasPendingDomUpdates = true;
    }
  }

  String createFrameDivHtml(FrameInfo frame) {
    final String classes = (frame.elapsedMs >= FrameInfo.kTargetMaxFrameTimeMs)
        ? 'frame-bar over-budget'
        : 'frame-bar';

    final int pixelWidth = (frame.elapsedMs * 3).round();
    return '<div class="$classes" style="width: ${pixelWidth}px"/>';
  }
}

/// Receive and log stdout / stderr events from the VM.
///
/// This class buffers the events for up to 1ms. This is in order to combine a
/// stdout message and its newline. Currently, `foo\n` is sent as two VM events;
/// we wait for up to 1ms when we get the `foo` event, to see if the next event
/// is a single newline. If so, we add the newline to the previous log message.
class _StdoutEventHandler {
  _StdoutEventHandler(this.loggingScreen, this.name, {this.isError = false});

  final LoggingScreen loggingScreen;
  final String name;
  final bool isError;

  LogData buffer;
  Timer timer;

  void handle(Event e) {
    final String message = decodeBase64(e.bytes);

    if (buffer != null) {
      timer?.cancel();

      if (message == '\n') {
        loggingScreen._log(LogData(
          buffer.kind,
          buffer.details + message,
          buffer.timestamp,
          summary: buffer.summary + message,
          isError: buffer.isError,
        ));
        buffer = null;
        return;
      }

      loggingScreen._log(buffer);
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
      loggingScreen._log(data);
    } else {
      buffer = data;
      timer = Timer(const Duration(milliseconds: 1), () {
        loggingScreen._log(buffer);
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

class LogKindColumn extends Column<LogData> {
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

class LogWhenColumn extends Column<LogData> {
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

class LogMessageColumn extends Column<LogData> {
  LogMessageColumn() : super.wide('Message');

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
      return escape(log.summary ?? log.details);
    }
  }
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

class LogDetailsUI extends CoreElement {
  LogDetailsUI() : super('div', classes: 'full-size') {
    layoutVertical();
    flex();

    add(<CoreElement>[
      content = div(c: 'log-details table-border')
        ..flex()
        ..add(message = div(c: 'pre-wrap monospace')),
    ]);
  }

  static const JsonEncoder jsonEncoder = JsonEncoder.withIndent('  ');

  LogData data;

  CoreElement content;
  CoreElement message;

  InspectorTreeHtml tree;

  void setData(LogData data) {
    // Reset the vertical scroll value if any.
    content.element.scrollTop = 0;

    this.data = data;

    tree = null;

    if (data == null) {
      message.text = '';
      return;
    }

    if (data.node != null) {
      message.clear();
      tree = InspectorTreeHtml(
        summaryTree: false,
        treeType: FlutterTreeType.widget,
        onSelectionChange: () {
          final InspectorTreeNode node = tree.selection;
          if (node != null) {
            tree.maybePopulateChildren(node);
          }
          node.diagnostic.setSelectionInspector(false);
          // TODO(jacobr): warn if the selection can't be set as the node is
          // stale which is likely if this is an old log entry.
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
      message.add(tree.element);

      return;
    }

    // See if we need to asynchronously compute the log entry details.
    if (data.needsComputing) {
      message.text = '';

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
        message.text = jsonEncoder.convert(result);
      } catch (e) {
        message.text = data.details;
      }
    } else {
      message.text = data.details;
    }
  }
}

class FrameInfo {
  FrameInfo(this.number, this.elapsedMs, this.startTimeMs);

  static const double kTargetMaxFrameTimeMs = 1000.0 / 60;

  static FrameInfo from(Map<String, dynamic> data) {
    return FrameInfo(
        data['number'], data['elapsed'] / 1000, data['startTime'] / 1000);
  }

  final int number;
  final num elapsedMs;
  final num startTimeMs;

  num get endTimeMs => startTimeMs + elapsedMs;

  @override
  String toString() => 'frame $number ${elapsedMs.toStringAsFixed(1)}ms';
}

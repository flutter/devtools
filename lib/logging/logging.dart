// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools/vm_service_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../tables.dart';
import '../timeline/fps.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../utils.dart';

// TODO(devoncarew): filtering, and enabling additional logging

// TODO(devoncarew): don't update DOM when we're not active; update once we return

// For performance reasons, we drop old logs in batches, so the log will grow
// to kMaxLogItemsUpperBound then truncate to kMaxLogItemsLowerBound.
const int kMaxLogItemsLowerBound = 5000;
const int kMaxLogItemsUpperBound = 5500;
final DateFormat timeFormat = new DateFormat('HH:mm:ss.SSS');

class LoggingScreen extends Screen {
  LoggingScreen()
      : super(name: 'Logs', id: 'logs', iconClass: 'octicon-clippy') {
    logCountStatus = new StatusItem();
    logCountStatus.element.text = '';
    addStatusItem(logCountStatus);

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  Table<LogData> loggingTable;
  StatusItem logCountStatus;
  SetStateMixin loggingStateMixin = new SetStateMixin();

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    this.framework = framework;

    LogDetailsUI logDetailsUI;

    mainDiv.add(<CoreElement>[
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..layoutHorizontal()
            ..clazz('align-items-center')
            ..add(<CoreElement>[
              span()..flex(),
              new PButton('Clear logs')
                ..small()
                ..click(_clear),
            ])
        ]),
      _createTableView()
        ..clazz('section')
        ..flex(),
      div(c: 'section table-border')
        ..layoutVertical()
        ..add(logDetailsUI = new LogDetailsUI()),
    ]);

    loggingTable.onSelect.listen((LogData selection) {
      logDetailsUI.setData(selection);
    });
  }

  CoreElement _createTableView() {
    loggingTable = new Table<LogData>.virtual(isReversed: true);

    loggingTable.addColumn(new LogWhenColumn());
    loggingTable.addColumn(new LogKindColumn());
    loggingTable.addColumn(new LogMessageColumn());

    loggingTable.setRows(data);

    _updateStatus();

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
    data.clear();
    loggingTable.setRows(data);
    _updateStatus();
  }

  // TODO(devoncarew): Update this url.
  @override
  HelpInfo get helpInfo =>
      new HelpInfo(title: 'logs view docs', url: 'http://www.cheese.com');

  void _handleConnectionStart(VmServiceWrapper service) {
    if (ref == null) {
      return;
    }

    // TODO(devoncarew): Add support for additional events, like 'inspect', ...

    // Log stdout events.
    final _StdoutEventHandler stdoutHandler =
        new _StdoutEventHandler(this, 'stdout');
    service.onStdoutEvent.listen((Event e) {
      stdoutHandler.handle(e);
    });

    // Log stderr events.
    final _StdoutEventHandler stderrHandler =
        new _StdoutEventHandler(this, 'stderr', isError: true);
    service.onStderrEvent.listen((Event e) {
      stderrHandler.handle(e);
    });

    // Log GC events.
    service.onGCEvent.listen((Event e) {
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
      _log(new LogData('gc', message, e.timestamp, summary: summary));
    });

    // Log `dart:developer` `log` events.
    service.onEvent('_Logging').listen((Event e) {
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
        detailsComputer = new Future<String>(() async {
          // Get the full string value of the message.
          String result =
              await _retrieveFullStringValue(service, e.isolate, messageRef);

          // Get information about the error object. Some users of the
          // dart:developer log call may pass a data payload in the `error`
          // field, encoded as a json encoded string, so handle that case..
          if (_isNotNull(error)) {
            if (error.valueAsString != null) {
              final String errorString =
                  await _retrieveFullStringValue(service, e.isolate, error);
              result += '\n\n$errorString';
            } else {
              // Call `toString()` on the error object and display that.
              final dynamic toStringResult = await service
                  .invoke(e.isolate.id, error.id, 'toString', <String>[]);

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

      _log(new LogData(
        loggerName,
        details,
        e.timestamp,
        isError: isError,
        summary: summary,
        detailsComputer: detailsComputer,
      ));
    });

    // Log Flutter frame events.
    service.onExtensionEvent.listen((Event e) {
      if (e.extensionKind == 'Flutter.Frame') {
        final FrameInfo frame = FrameInfo.from(e.extensionData.data);

        final String frameId = '#${frame.number}';
        final String frameInfo =
            '<span class="pre">$frameId ${frame.elapsedMs.toStringAsFixed(1).padLeft(4)}ms </span>';
        final String div = createFrameDivHtml(frame);

        _log(new LogData(
          '${e.extensionKind.toLowerCase()}',
          jsonEncode(e.extensionData.data),
          e.timestamp,
          summaryHtml: '$frameInfo$div',
        ));
      } else {
        _log(new LogData(
          '${e.extensionKind.toLowerCase()}',
          jsonEncode(e.json),
          e.timestamp,
          summary: e.json.toString(),
        ));
      }
    });
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
      loggingTable.setRows(data);
      _updateStatus();
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
        loggingScreen._log(new LogData(
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

    final LogData data = new LogData(
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
      timer = new Timer(const Duration(milliseconds: 1), () {
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
  });

  final String kind;
  final int timestamp;
  final bool isError;
  final String summary;
  final String summaryHtml;

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
  dynamic getValue(LogData item) {
    final String cssClass = getCssClassForEventKind(item);

    return '<span class="label $cssClass">${item.kind}</span>';
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
  dynamic getValue(LogData item) => item.timestamp;

  @override
  String render(dynamic value) {
    return timeFormat.format(new DateTime.fromMillisecondsSinceEpoch(value));
  }
}

class LogMessageColumn extends Column<LogData> {
  LogMessageColumn() : super('Message', wide: true);

  @override
  String get cssClass => 'pre-wrap monospace';

  @override
  bool get usesHtml => true;

  @override
  bool get supportsSorting => false;

  @override
  dynamic getValue(LogData item) => item;

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
  } else if (item.kind.startsWith('flutter')) {
    cssClass = 'flutter';
  } else if (item.kind == 'gc') {
    cssClass = 'gc';
  }

  return cssClass;
}

class LogDetailsUI extends CoreElement {
  LogDetailsUI() : super('div') {
    layoutVertical();

    add(<CoreElement>[
      content = div(c: 'log-details secondary-area')
        ..add(message = div(c: 'pre-wrap monospace')),
    ]);
  }

  static const JsonEncoder jsonEncoder = JsonEncoder.withIndent('  ');

  LogData data;

  CoreElement content;
  CoreElement message;

  void setData(LogData data) {
    // Reset the vertical scroll value if any.
    content.element.scrollTop = 0;

    this.data = data;

    if (data == null) {
      message.text = '';
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
        // If the string decodes properly, than format the json.
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

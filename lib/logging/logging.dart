// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../tables.dart';
import '../timeline/fps.dart';
import '../ui/elements.dart';
import '../utils.dart';

// TODO(devoncarew): inspect calls

// TODO(devoncarew): filtering, and enabling additional logging

// TODO(devoncarew): don't update DOM when we're not active; update once we return

// For performance reasons, we drop old logs in batches, so the log will grow
// to kMaxLogItemsUpperBound then truncate to kMaxLogItemsLowerBound.
const int kMaxLogItemsLowerBound = 5000;
const int kMaxLogItemsUpperBound = 5500;
DateFormat timeFormat = new DateFormat('HH:mm:ss.SSS');

class LoggingScreen extends Screen {
  Table<LogData> loggingTable;
  StatusItem logCountStatus;
  SetStateMixin loggingStateMixin = new SetStateMixin();

  LoggingScreen()
      : super(name: 'Logs', id: 'logs', iconClass: 'octicon-clippy') {
    logCountStatus = new StatusItem();
    logCountStatus.element.text = '';
    addStatusItem(logCountStatus);

    serviceInfo.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceInfo.hasConnection) {
      _handleConnectionStart(serviceInfo.service);
    }
    serviceInfo.onConnectionClosed.listen(_handleConnectionStop);
  }

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    this.framework = framework;

    LogDetailsUI logDetailsUI;

    mainDiv.add(<CoreElement>[
      _createTableView()
        ..clazz('section')
        ..flex(),
      div(c: 'section')
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
    final int count = loggingTable.rows.length;
    logCountStatus.element.text = '${nf.format(count)} events';
  }

  @override
  HelpInfo get helpInfo =>
      new HelpInfo(title: 'logs view docs', url: 'http://www.cheese.com');

  void _handleConnectionStart(VmService service) {
    if (ref == null) {
      return;
    }

    // TODO(devoncarew): Add support for additional events, like 'inspect', ...

    // Log stdout events.
    service.onStdoutEvent.listen((Event e) {
      final String message = decodeBase64(e.bytes);
      String summary = message;
      if (message.length > 200) {
        summary = message.substring(0, 200) + '…';
      }
      summary = summary.replaceAll('\t', r'\t');
      summary = summary.replaceAll('\r', r'\r');
      summary = summary.replaceAll('\n', r'\n');
      _log(new LogData('stdout', message, e.timestamp, summary: summary));
    });

    // Log stderr events.
    service.onStderrEvent.listen((Event e) {
      final String message = decodeBase64(e.bytes);
      String summary = message;
      if (message.length > 200) {
        summary = message.substring(0, 200) + '…';
      }
      summary = summary.replaceAll('\t', r'\t');
      summary = summary.replaceAll('\r', r'\r');
      summary = summary.replaceAll('\n', r'\n');
      _log(new LogData(
        'stderr',
        message,
        e.timestamp,
        summary: summary,
        isError: true,
      ));
    });

    // Log GC events.
    service.onGCEvent.listen((Event e) {
      final Map<dynamic, dynamic> newSpace = e.json['new'];
      final Map<dynamic, dynamic> oldSpace = e.json['old'];
      final Map<dynamic, dynamic> isolateRef = e.json['isolate'];

      final int usedBytes = newSpace['used'] + oldSpace['used'];
      final int capacityBytes = newSpace['capacity'] + oldSpace['capacity'];

      final String summary = '${isolateRef['name']} • '
          '${e.json['reason']} collection • '
          '${printMb(usedBytes)} MB used of ${printMb(capacityBytes)} MB';
      final Map<String, dynamic> event = <String, dynamic>{
        'reason': e.json['reason'],
        'new': newSpace,
        'old': oldSpace,
        'isolate': isolateRef,
      };
      final String message = jsonEncode(event);
      _log(new LogData('gc', message, e.timestamp, summary: summary));
    });

    // Log `dart:developer` `log` events.
    service.onEvent('_Logging').listen((Event e) {
      final dynamic logRecord = e.json['logRecord'];

      String loggerName = _valueAsString(logRecord['loggerName']);
      if (loggerName == null || loggerName.isEmpty) {
        loggerName = 'log';
      }
      // TODO(devoncarew): show level, with some indication of severity
      final int level = logRecord['level'];
      String message = _valueAsString(logRecord['message']);
      // TODO(devoncarew): The VM is not sending the error correctly.
      final dynamic error = logRecord['error'];
      final dynamic stackTrace = logRecord['stackTrace'];

      if (_isNotNull(error)) {
        message = message + '\nerror: ${_valueAsString(error)}';
      }
      if (_isNotNull(stackTrace)) {
        message = message + '\n${_valueAsString(stackTrace)}';
      }

      final bool isError =
          level != null && level >= Level.SEVERE.value ? true : false;

      _log(new LogData(
        loggerName,
        jsonEncode(logRecord),
        e.timestamp,
        isError: isError,
        summary: message,
      ));
    });

    // Log Flutter frame events.
    service.onExtensionEvent.listen((Event e) {
      if (e.extensionKind == 'Flutter.Frame') {
        final FrameInfo frame = FrameInfo.from(e.extensionData.data);

        final String frameInfo =
            '<span class="pre">${frame.elapsedMs.toStringAsFixed(1).padLeft(4)}ms </span>';
        final String div = createFrameDivHtml(frame);

        _log(new LogData('${e.extensionKind.toLowerCase()}',
            jsonEncode(e.extensionData.data), e.timestamp,
            summaryHtml: '$frameInfo$div'));
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

  void _handleConnectionStop(dynamic event) {}

  List<LogData> data = <LogData>[];

  void _log(LogData log) {
    // Insert the new item and clamped the list to kMaxLogItemsLength. The table
    // is rendered reversed so new items are at the top but we can use .add() here
    // which is must faster than inserting at the start of the list.
    data.add(log);
    // Note: We need to drop rows from the start because we want to drop old rows
    // but because that's expensive, we only do it periodically (eg. when the list
    // is 500 rows more).
    if (data.length > kMaxLogItemsUpperBound) {
      int itemsToRemove = data.length - kMaxLogItemsLowerBound;
      // Ensure we remove an even number of rows to keep the alternating background
      // in-sync.
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

bool _isNotNull(dynamic serviceRef) {
  return serviceRef != null && serviceRef['kind'] != 'Null';
}

String _valueAsString(dynamic serviceRef) {
  return serviceRef == null ? null : serviceRef['valueAsString'];
}

class LogData {
  final String kind;
  final String message;
  final int timestamp;
  final bool isError;
  final String summary;
  final String summaryHtml;

  LogData(
    this.kind,
    this.message,
    this.timestamp, {
    this.isError = false,
    this.summary,
    this.summaryHtml,
  });
}

class LogKindColumn extends Column<LogData> {
  LogKindColumn() : super('Kind');

  @override
  bool get supportsSorting => false;

  @override
  bool get usesHtml => true;

  @override
  String get cssClass => 'right';

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
      return escape(log.summary ?? log.message);
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
  static const JsonEncoder jsonEncoder = JsonEncoder.withIndent('  ');

  CoreElement content, message;

  LogDetailsUI() : super('div') {
    layoutVertical();

    add(<CoreElement>[
      content = div(c: 'log-details')
        ..add(message = div(c: 'pre-wrap monospace')),
    ]);
  }

  void setData(LogData data) {
    // Reset the vertical scroll value if any.
    content.element.scrollTop = 0;

    if (data != null) {
      if (data.message.startsWith('{') && data.message.endsWith('}')) {
        try {
          // If the string decodes properly, than format the json.
          final dynamic result = jsonDecode(data.message);
          message.text = jsonEncoder.convert(result);
        } catch (e) {
          message.text = data.message;
        }
      } else {
        message.text = data.message;
      }
    } else {
      message.text = '';
    }
  }
}

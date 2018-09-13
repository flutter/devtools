// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

// TODO(devoncarew): a more efficient table; we need to virtualize it

// TODO(devoncarew): don't update DOM when we're not active; update once we return

const int kMaxLogItemsLength = 5000;
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
        ..flex(4),
      div(c: 'section')
        ..layoutVertical()
        ..flex()
        ..add(logDetailsUI = new LogDetailsUI()),
    ]);

    // TODO(dantup): Can we (should we?) detect when the content is overflowed
    // in the table, and only show the defaults?
    loggingTable.onSelect
        .listen((LogData selection) => logDetailsUI.data = selection);

    serviceInfo.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceInfo.hasConnection) {
      _handleConnectionStart(serviceInfo.service);
    }
    serviceInfo.onConnectionClosed.listen(_handleConnectionStop);
  }

  CoreElement _createTableView() {
    loggingTable = new Table<LogData>.virtual();

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

    // TODO(devoncarew): inspect, ...

    // Log stdout and stderr events.
    service.onStdoutEvent.listen((Event e) {
      String message = decodeBase64(e.bytes);
      // TODO(devoncarew): Have the UI provide a way to show untruncated data.
      if (message.length > 500) {
        message = message.substring(0, 500) + '…';
      }
      _log(new LogData('stdout', message, e.timestamp));
    });
    service.onStderrEvent.listen((Event e) {
      final String message = decodeBase64(e.bytes);
      _log(new LogData('stderr', message, e.timestamp, error: true));
    });

    // Log GC events.
    service.onGCEvent.listen((Event e) {
      final dynamic json = e.json;
      final String message = 'gc reason: ${json['reason']}\n'
          'new: ${json['new']}\n'
          'old: ${json['old']}\n';
      _log(new LogData('gc', message, e.timestamp));
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
      _log(new LogData(loggerName, message, e.timestamp, error: isError));
    });

    // Log Flutter frame events.
    service.onExtensionEvent.listen((Event e) {
      if (e.extensionKind == 'Flutter.Frame') {
        final FrameInfo frame = FrameInfo.from(e.extensionData.data);

        final String div = createFrameDivHtml(frame);

        _log(new LogData(
          '${e.extensionKind.toLowerCase()}',
          'frame ${frame.number} ${frame.elapsedMs.toStringAsFixed(1).padLeft(4)}ms',
          e.timestamp,
          extraHtml: div,
        ));
      } else {
        _log(new LogData('${e.extensionKind.toLowerCase()}', e.json.toString(),
            e.timestamp));
      }
    });
  }

  void _handleConnectionStop(dynamic event) {}

  List<LogData> data = <LogData>[];
  void _log(LogData log) {
    // TODO(devoncarew): make this much more efficient
    // TODO(dantup): Maybe add to a small buffer and then after xms insert
    // that full buffer into the list here to avoid a list rebuild on every single
    // insert.
    // Or maybe append to the end of the list and reverse index-based operations?

    // Build a new list that has 1 item more (clamped at kMaxLogItemsLength)
    // and insert this new item at the start, followed by the required number
    // of items from the old data.
    final int totalItems = (data.length + 1).clamp(0, kMaxLogItemsLength);
    data = List<LogData>(totalItems)
      ..[0] = log
      ..setRange(1, totalItems, data);

    if (visible && loggingTable != null) {
      loggingTable.setRows(data, anchorAlternatingRowsToBottom: true);
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
  final bool error;
  final String extraHtml;

  LogData(this.kind, this.message, this.timestamp,
      {this.error = false, this.extraHtml});
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

    if (log.extraHtml != null) {
      return '${log.message} ${log.extraHtml}';
    } else {
      return log.message; // TODO(devoncarew): escape html
    }
  }
}

String getCssClassForEventKind(LogData item) {
  String cssClass = '';

  if (item.kind == 'stderr' || item.error) {
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
  LogData _data;

  CoreElement content, timestamp, kind, message;

  LogDetailsUI() : super('div') {
    attribute('hidden');
    layoutVertical();
    flex();

    add(<CoreElement>[
      content = div(c: 'log-details')
        ..flex()
        ..add(kind = span())
        ..add(timestamp = span())
        ..add(message = div(c: 'pre-wrap monospace')),
    ]);
  }

  LogData get data => _data;
  set data(LogData value) {
    _data = value;

    if (_data != null) {
      timestamp.text = timeFormat
          .format(new DateTime.fromMillisecondsSinceEpoch(_data.timestamp));
      kind
        ..text = _data.kind
        ..clazz('label', removeOthers: true)
        ..clazz(getCssClassForEventKind(data));
      // TODO: Can we format the JSON better?
      message.text = _data.message;
    }
    attribute('hidden', _data == null);
  }
}

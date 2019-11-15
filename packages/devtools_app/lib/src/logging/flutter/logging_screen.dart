// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../../flutter/controllers.dart';
import '../../flutter/screen.dart';
import '../../flutter/table.dart';
import '../../table_data.dart';
import '../../ui/flutter/service_extension_widgets.dart';
import '../logging_controller.dart';

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  const LoggingScreen() : super('Logging');

  @override
  Widget build(BuildContext context) {
    return LoggingScreenBody();
  }

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      text: 'Logging',
      icon: Icon(Octicons.getIconData('clippy')),
    );
  }
}

class LoggingScreenBody extends StatefulWidget {
  @override
  _LoggingScreenState createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreenBody> {
  LoggingController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller?.onLogsUpdated?.unregister(this);
    controller = Controllers.of(context).logging;
    controller.onLogsUpdated.register(this, () {
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.onLogsUpdated.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RaisedButton(
            child: const Text('Clear logs'),
            onPressed: _clearLogs,
          ),
          StructuredErrorsToggle(),
        ],
      ),
      Expanded(
        child: LogsTable(
          data: controller.data,
        ),
      ),
    ]);
  }

  void _clearLogs() {
    setState(() {
      controller.clear();
    });
  }
}

class LogsTable extends StatelessWidget {
  const LogsTable({Key key, this.data}) : super(key: key);
  final List<LogData> data;

  List<ColumnData<LogData>> get columns => [
        _WhenColumn(),
        _KindColumn(),
        _MessageColumn((message) => message),
      ];

  @override
  Widget build(BuildContext context) {
    return FlatTable<LogData>(
      columns: columns,
      data: data,
      keyFactory: (LogData data) => '${data.timestamp}${data.summary}',
    );
  }
}

// TODO(https://github.com/flutter/devtools/issues/1258): merge these classes
// with their parents when we turn down the html version of the app.

class _WhenColumn extends LogWhenColumn {
  @override
  double get fixedWidthPx => 120;

  @override
  String getValue(LogData dataObject) => render(dataObject.timestamp);
}

class _KindColumn extends LogKindColumn {
  @override
  String getValue(LogData dataObject) => dataObject.kind;

  @override
  double get fixedWidthPx => 120;
}

class _MessageColumn extends LogMessageColumn {
  _MessageColumn(String Function(String) logMessageToHtml)
      : super(logMessageToHtml);

  /// TODO(djshuckerow): Do better than showing raw HTML here.
  @override
  String getValue(LogData dataObject) => render(dataObject);
}

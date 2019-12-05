// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/controllers.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/table.dart';
import '../../table_data.dart';
import '../../ui/flutter/service_extension_widgets.dart';
import '../logging_controller.dart';

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  const LoggingScreen() : super();

  @override
  Widget build(BuildContext context) {
    return LoggingScreenBody();
  }

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Logging',
      icon: Icon(Octicons.clippy),
    );
  }
}

class LoggingScreenBody extends StatefulWidget {
  @override
  _LoggingScreenState createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreenBody>
    with AutoDisposeMixin {
  LoggingController get controller => Controllers.of(context).logging;
  LogData selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    cancel();
    addAutoDisposeListener(controller.onLogsUpdated);
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
        child: Split(
          axis: Split.axisFor(context, 1.0),
          firstChild: LogsTable(
            data: controller.data,
            onItemSelected: _select,
          ),
          secondChild: LogDetails(log: selected),
          initialFirstFraction: 0.6,
        ),
      ),
    ]);
  }

  void _select(LogData log) {
    setState(() => selected = log);
  }

  void _clearLogs() {
    setState(() {
      controller.clear();
    });
  }
}

class LogsTable extends StatelessWidget {
  const LogsTable({Key key, this.data, this.onItemSelected}) : super(key: key);
  final List<LogData> data;
  final ItemCallback<LogData> onItemSelected;

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
      keyFactory: (LogData data) => ValueKey<LogData>(data),
      onItemSelected: onItemSelected,
    );
  }
}

class LogDetails extends StatefulWidget {
  const LogDetails({Key key, @required this.log}) : super(key: key);
  final LogData log;

  @override
  _LogDetailsState createState() => _LogDetailsState();
}

class _LogDetailsState extends State<LogDetails>
    with SingleTickerProviderStateMixin {
  AnimationController crossFade;

  @override
  void initState() {
    super.initState();
    crossFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _oldLog = widget.log;
            crossFade.value = 0.0;
          });
        }
      });
    // We'll use a linear curve for this animation, so no curve needed.
    _computeLogDetails();
  }

  @override
  void dispose() {
    crossFade.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LogDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.log != oldWidget.log) {
      _oldLog = oldWidget.log;
      crossFade.forward();
    }
    _computeLogDetails();
  }

  Future<void> _computeLogDetails() async {
    if (widget.log?.needsComputing ?? false) {
      await widget.log.compute();
      setState(() {});
    }
  }

  LogData _oldLog;

  bool showInspector(LogData log) => log != null && log.node != null;
  bool showSimple(LogData log) =>
      log != null && log.node == null && !log.needsComputing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: crossFade,
      builder: (context, _) {
        return Container(
          color: Theme.of(context).cardColor,
          child: Stack(children: [
            Opacity(
              opacity: crossFade.value,
              child: _buildContent(context, widget.log),
            ),
            Opacity(
              opacity: 1 - crossFade.value,
              child: _buildContent(context, _oldLog),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, LogData log) {
    if (log == null) return const SizedBox();
    if (log.needsComputing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (showInspector(log)) return _buildInspector(context, log);
    if (showSimple(log)) return _buildSimpleLog(context, log);
    return const SizedBox();
  }

  // TODO(https://github.com/flutter/devtools/issues/1370): implement this.
  Widget _buildInspector(BuildContext context, LogData log) => const SizedBox();

  Widget _buildSimpleLog(BuildContext context, LogData log) {
    // TODO(https://github.com/flutter/devtools/issues/1339): Present with monospaced fonts.
    return Scrollbar(
      child: SingleChildScrollView(
        child: Text(
          log.prettyPrinted ?? '',
          style: Theme.of(context).textTheme.subhead,
        ),
      ),
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
  String getValue(LogData dataObject) =>
      dataObject.summary ?? dataObject.details;
}

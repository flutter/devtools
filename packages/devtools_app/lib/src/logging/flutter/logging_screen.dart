// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/controllers.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/table.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../table_data.dart';
import '../../ui/flutter/service_extension_widgets.dart';
import '../../utils.dart';
import '../logging_controller.dart';

// TODO(devoncarew): Show rows starting from the top (and have them grow down).
// TODO(devoncarew): We should keep new items visible (if the last item was
// already visible).

// TODO(devoncarew): The last column of a table should take up all remaining
// width.

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  const LoggingScreen()
      : super(
          DevToolsScreenType.logging,
          title: 'Logging',
          icon: Octicons.clippy,
        );

  @override
  String get docPageId => 'logging';

  @override
  Widget build(BuildContext context) {
    return !(serviceManager.connectedApp.isFlutterWebAppNow &&
            serviceManager.connectedApp.isProfileBuildNow)
        ? const LoggingScreenBody()
        : const DisabledForFlutterWebProfileBuildMessage();
  }

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final LoggingController controller = Controllers.of(context).logging;

    return StreamBuilder<String>(
      initialData: controller.statusText,
      stream: controller.onLogStatusChanged,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        return Text(snapshot.data ?? '');
      },
    );
  }
}

class LoggingScreenBody extends StatefulWidget {
  const LoggingScreenBody();

  @override
  _LoggingScreenState createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreenBody>
    with AutoDisposeMixin {
  LogData selected;
  TextEditingController filterController;

  LoggingController get controller => Controllers.of(context).logging;

  @override
  void initState() {
    super.initState();

    filterController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    cancel();

    filterController.text = controller.filterText;
    filterController.addListener(() {
      controller.filterText = filterController.text;
    });

    addAutoDisposeListener(controller.onLogsUpdated, () {
      setState(() {
        if (selected != null) {
          final List<LogData> items = controller.filteredData;
          if (!items.contains(selected)) {
            selected = null;
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          clearButton(onPressed: _clearLogs),
          const Spacer(),
          Container(
            width: 200.0,
            height: 36.0,
            child: TextField(
              controller: filterController,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: 'Search',
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          StructuredErrorsToggle(),
        ],
      ),
      Expanded(
        child: Split(
          axis: Axis.vertical,
          initialFractions: const [0.78, 0.22],
          children: [
            LogsTable(
              data: controller.filteredData,
              onItemSelected: _select,
            ),
            LogDetails(log: selected),
          ],
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
      selected = null;
    });
  }
}

class LogsTable extends StatelessWidget {
  LogsTable({Key key, this.data, this.onItemSelected}) : super(key: key);

  final List<LogData> data;
  final ItemCallback<LogData> onItemSelected;

  final ColumnData<LogData> when = _WhenColumn();
  final ColumnData<LogData> kind = _KindColumn();
  final ColumnData<LogData> message = _MessageColumn((message) => message);

  List<ColumnData<LogData>> get columns => [when, kind, message];

  @override
  Widget build(BuildContext context) {
    return FlatTable<LogData>(
      columns: columns,
      data: data,
      reverse: true,
      keyFactory: (LogData data) => ValueKey<LogData>(data),
      onItemSelected: onItemSelected,
      sortColumn: when,
      sortDirection: SortDirection.ascending,
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
    crossFade = defaultAnimationController(this)
      ..addStatusListener((status) {
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: crossFade.value,
                child: _buildContent(context, widget.log),
              ),
              Opacity(
                opacity: 1 - crossFade.value,
                child: _buildContent(context, _oldLog),
              ),
            ],
          ),
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
    return Scrollbar(
      child: SingleChildScrollView(
        child: Text(
          log.prettyPrinted ?? '',
          style: fixedFontStyle(context),
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

class _KindColumn extends LogKindColumn implements ColumnRenderer<LogData> {
  @override
  String getValue(LogData dataObject) => dataObject.kind;

  @override
  double get fixedWidthPx => 140;

  @override
  Widget build(BuildContext context, LogData item) {
    final String kind = item.kind;

    Color color = const Color.fromARGB(0xff, 0x61, 0x61, 0x61);

    if (kind == 'stderr' || item.isError || kind == 'flutter.error') {
      color = const Color.fromARGB(0xff, 0xF4, 0x43, 0x36);
    } else if (kind == 'stdout') {
      color = const Color.fromARGB(0xff, 0x78, 0x90, 0x9C);
    } else if (kind.startsWith('flutter')) {
      color = const Color.fromARGB(0xff, 0x00, 0x91, 0xea);
    } else if (kind == 'gc') {
      color = const Color.fromARGB(0xff, 0x42, 0x42, 0x42);
    }

    // Use a font color that contrasts with the colored backgrounds.
    final textStyle = Theme.of(context)
        .primaryTextTheme
        .bodyText2
        .copyWith(fontFamily: 'RobotoMono', fontSize: 13.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Text(
        kind,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );
  }
}

class _MessageColumn extends LogMessageColumn
    implements ColumnRenderer<LogData> {
  _MessageColumn(String Function(String) logMessageToHtml)
      : super(logMessageToHtml);

  @override
  String getValue(LogData dataObject) =>
      dataObject.summary ?? dataObject.details;

  @override
  Widget build(BuildContext context, LogData data) {
    if (data.kind == 'flutter.frame') {
      const Color color = Color.fromARGB(0xff, 0x00, 0x91, 0xea);
      final Text text = Text(
        '${getDisplayValue(data)}',
        overflow: TextOverflow.ellipsis,
        style: fixedFontStyle(context),
      );

      double frameLength = 0.0;
      try {
        final int micros = jsonDecode(data.details)['elapsed'];
        frameLength = micros * 3.0 / 1000.0;
      } catch (e) {
        // ignore
      }

      return Row(
        children: <Widget>[
          text,
          Flexible(
            child: Container(
              height: 12.0,
              width: frameLength,
              decoration: const BoxDecoration(color: color),
            ),
          ),
        ],
      );
    } else {
      return null;
    }
  }
}

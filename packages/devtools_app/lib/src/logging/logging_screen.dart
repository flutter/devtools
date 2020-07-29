// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../console.dart';
import '../octicons.dart';
import '../screen.dart';
import '../split.dart';
import '../table.dart';
import '../table_data.dart';
import '../theme.dart';
import '../ui/service_extension_widgets.dart';
import '../utils.dart';
import 'logging_controller.dart';

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  const LoggingScreen()
      : super('logging', title: 'Logging', icon: Octicons.clippy);

  @override
  String get docPageId => screenId;

  @override
  Widget build(BuildContext context) => const LoggingScreenBody();

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final LoggingController controller =
        Provider.of<LoggingController>(context);

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

  LoggingController controller;

  @override
  void initState() {
    super.initState();

    filterController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<LoggingController>(context);
    if (newController == controller) return;
    controller = newController;

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
        children: [
          clearButton(onPressed: _clearLogs),
          const Spacer(),
          Container(
            width: defaultSearchTextWidth,
            height: defaultSearchTextHeight,
            child: TextField(
              controller: filterController,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: 'Filter',
                // TODO(devoncarew): Include hint text (this currently has an
                // issue w/ sizing of the search field's contents).
                //hintText: 'term -term',
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
          initialFractions: const [0.72, 0.28],
          children: [
            OutlineDecoration(
              child: LogsTable(
                data: controller.filteredData,
                onItemSelected: _select,
              ),
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
  final ColumnData<LogData> message = _MessageColumn();

  List<ColumnData<LogData>> get columns => [when, kind, message];

  @override
  Widget build(BuildContext context) {
    return FlatTable<LogData>(
      columns: columns,
      data: data,
      autoScrollContent: true,
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

  static const copyToClipboardButtonKey =
      Key('log_details_copy_to_clipboard_button');
}

class _LogDetailsState extends State<LogDetails>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();

    _computeLogDetails();
  }

  @override
  void didUpdateWidget(LogDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.log != oldWidget.log) {
      _computeLogDetails();
    }
  }

  Future<void> _computeLogDetails() async {
    if (widget.log?.needsComputing ?? false) {
      await widget.log.compute();
      setState(() {});
    }
  }

  bool showInspector(LogData log) => log != null && log.node != null;

  bool showSimple(LogData log) =>
      log != null && log.node == null && !log.needsComputing;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _buildContent(context, widget.log),
    );
  }

  Widget _buildContent(BuildContext context, LogData log) {
    if (showInspector(log)) {
      return _buildInspector(context, log);
    } else {
      return Stack(
        children: [
          _buildSimpleLog(context, log),
          if (log != null && log.needsComputing)
            const Center(child: CircularProgressIndicator()),
        ],
      );
    }
  }

  // TODO(#1370): implement this.
  Widget _buildInspector(BuildContext context, LogData log) => const SizedBox();

  Widget _buildSimpleLog(BuildContext context, LogData log) {
    final disabled = log?.details == null || log.details.isEmpty;

    return OutlineDecoration(
      child: Console(
        title: areaPaneHeader(
          context,
          title: 'Details',
          needsTopBorder: false,
          actions: [
            CopyToClipboardControl(
              dataProvider: disabled ? null : () => log?.prettyPrinted,
              buttonKey: LogDetails.copyToClipboardButtonKey,
            ),
          ],
        ),
        lines: log?.prettyPrinted?.split('\n'),
      ),
    );
  }
}

class _WhenColumn extends ColumnData<LogData> {
  _WhenColumn() : super('When');

  @override
  bool get supportsSorting => false;

  @override
  double get fixedWidthPx => 120;

  @override
  String getValue(LogData dataObject) => dataObject.timestamp == null
      ? ''
      : timeFormat
          .format(DateTime.fromMillisecondsSinceEpoch(dataObject.timestamp));
}

class _KindColumn extends ColumnData<LogData>
    implements ColumnRenderer<LogData> {
  _KindColumn() : super('Kind');

  @override
  bool get supportsSorting => false;

  @override
  double get fixedWidthPx => 145;

  @override
  String getValue(LogData dataObject) => dataObject.kind;

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

class _MessageColumn extends ColumnData<LogData>
    implements ColumnRenderer<LogData> {
  _MessageColumn() : super.wide('Message');

  @override
  bool get supportsSorting => false;

  @override
  String getValue(LogData dataObject) =>
      dataObject.summary ?? dataObject.details;

  @override
  Widget build(BuildContext context, LogData data) {
    if (data.kind == 'flutter.frame') {
      const Color color = Color.fromARGB(0xff, 0x00, 0x91, 0xea);
      final Text text = Text(
        getDisplayValue(data),
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
    } else if (data.kind == 'stdout') {
      return RichText(
        text: TextSpan(
          children: processAnsiTerminalCodes(
            // TODO(helin24): Recompute summary length considering ansi codes.
            //  The current summary is generally the first 200 chars of details.
            getDisplayValue(data),
            fixedFontStyle(context),
          ),
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    } else {
      return null;
    }
  }
}

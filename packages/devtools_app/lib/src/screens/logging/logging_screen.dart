// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics.dart' as ga;
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/console.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/colors.dart';
import '../../ui/filter.dart';
import '../../ui/icons.dart';
import '../../ui/search.dart';
import '../../ui/service_extension_widgets.dart';
import 'logging_controller.dart';

final loggingSearchFieldKey = GlobalKey(debugLabel: 'LoggingSearchFieldKey');

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  const LoggingScreen()
      : super(
          id,
          title: 'Logging',
          icon: Octicons.clippy,
        );

  static const id = 'logging';

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

  static const filterQueryInstructions = '''
Type a filter query to show or hide specific logs.

Any text that is not paired with an available filter key below will be queried against all categories (kind, message).

Available filters:
    'kind', 'k'       (e.g. 'k:flutter.frame', '-k:gc,stdout')

Example queries:
    'my log message k:stdout,stdin'
    'flutter -k:gc'
''';

  @override
  _LoggingScreenState createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreenBody>
    with AutoDisposeMixin, SearchFieldMixin<LoggingScreenBody> {
  LogData? selected;

  LoggingController? controller;

  late List<LogData> filteredLogs;

  @override
  void initState() {
    super.initState();
    ga.screen(LoggingScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<LoggingController>(context);
    if (newController == controller) return;
    controller = newController;

    cancelListeners();

    filteredLogs = controller!.filteredData.value;
    addAutoDisposeListener(controller!.filteredData, () {
      setState(() {
        filteredLogs = controller!.filteredData.value;
      });
    });

    selected = controller!.selectedLog.value;
    addAutoDisposeListener(controller!.selectedLog, () {
      setState(() {
        selected = controller!.selectedLog.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildLoggingControls(),
      const SizedBox(height: denseRowSpacing),
      Expanded(
        child: _buildLoggingBody(),
      ),
    ]);
  }

  Widget _buildLoggingControls() {
    final hasData = controller!.filteredData.value.isNotEmpty;
    return Row(
      children: [
        ClearButton(onPressed: controller!.clear),
        const Spacer(),
        StructuredErrorsToggle(),
        const SizedBox(width: denseSpacing),
        // TODO(kenz): fix focus issue when state is refreshed
        Container(
          width: wideSearchTextWidth,
          height: defaultTextFieldHeight,
          child: buildSearchField(
            controller: controller!,
            searchFieldKey: loggingSearchFieldKey,
            searchFieldEnabled: hasData,
            shouldRequestFocus: false,
            supportsNavigation: true,
          ),
        ),
        const SizedBox(width: denseSpacing),
        FilterButton(
          onPressed: _showFilterDialog,
          isFilterActive: filteredLogs.length != controller!.data.length,
        ),
      ],
    );
  }

  Widget _buildLoggingBody() {
    return Split(
      axis: Axis.vertical,
      initialFractions: const [0.72, 0.28],
      children: [
        OutlineDecoration(
          child: LogsTable(
            data: filteredLogs,
            onItemSelected: controller!.selectLog,
            selectionNotifier: controller!.selectedLog,
            searchMatchesNotifier: controller!.searchMatches,
            activeSearchMatchNotifier: controller!.activeSearchMatch,
          ),
        ),
        LogDetails(log: selected),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog<LoggingController?, LogData>(
        controller: controller,
        queryInstructions: LoggingScreenBody.filterQueryInstructions,
        queryFilterArguments: controller!.filterArgs,
      ),
    );
  }
}

class LogsTable extends StatelessWidget {
  LogsTable({
    Key? key,
    required this.data,
    required this.onItemSelected,
    required this.selectionNotifier,
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
  }) : super(key: key);

  final List<LogData> data;
  final ItemCallback<LogData> onItemSelected;
  final ValueListenable<LogData> selectionNotifier;
  final ValueListenable<List<LogData>> searchMatchesNotifier;
  final ValueListenable<LogData> activeSearchMatchNotifier;

  final ColumnData<LogData> when = _WhenColumn();
  final ColumnData<LogData> kind = _KindColumn();
  final ColumnData<LogData> message = MessageColumn();

  List<ColumnData<LogData>> get columns => [when, kind, message];

  @override
  Widget build(BuildContext context) {
    return FlatTable<LogData>(
      columns: columns,
      data: data,
      autoScrollContent: true,
      keyFactory: (LogData? data) => ValueKey<LogData?>(data),
      onItemSelected: onItemSelected,
      selectionNotifier: selectionNotifier,
      sortColumn: when,
      secondarySortColumn: message,
      sortDirection: SortDirection.ascending,
      searchMatchesNotifier: searchMatchesNotifier,
      activeSearchMatchNotifier: activeSearchMatchNotifier,
    );
  }
}

class LogDetails extends StatefulWidget {
  const LogDetails({Key? key, required this.log}) : super(key: key);

  final LogData? log;

  @override
  _LogDetailsState createState() => _LogDetailsState();

  static const copyToClipboardButtonKey =
      Key('log_details_copy_to_clipboard_button');
}

class _LogDetailsState extends State<LogDetails>
    with SingleTickerProviderStateMixin {
  String? _lastDetails;
  ScrollController? scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
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
      await widget.log!.compute();
      setState(() {});
    }
  }

  bool showSimple(LogData log) => !log.needsComputing;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _buildContent(context, widget.log),
    );
  }

  Widget _buildContent(BuildContext context, LogData? log) {
    // TODO(#1370): Handle showing flutter errors in a structured manner.
    return Stack(
      children: [
        _buildSimpleLog(context, log),
        if (log != null && log.needsComputing)
          const CenteredCircularProgressIndicator(),
      ],
    );
  }

  Widget _buildSimpleLog(BuildContext context, LogData? log) {
    final disabled = log?.details == null || log!.details!.isEmpty;

    final details = log?.details;
    if (details != _lastDetails) {
      if (scrollController!.hasClients) {
        // Make sure we change the scroll if the log details shown have changed.
        scrollController!.jumpTo(0);
      }
      _lastDetails = details;
    }

    return OutlineDecoration(
      child: ConsoleFrame(
        title: AreaPaneHeader(
          title: const Text('Details'),
          needsTopBorder: false,
          rightActions: [
            CopyToClipboardControl(
              dataProvider: disabled ? null : () => log!.prettyPrinted!,
              buttonKey: LogDetails.copyToClipboardButtonKey,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: SingleChildScrollView(
            controller: scrollController,
            child: SelectableText(
              log?.prettyPrinted ?? '',
              textAlign: TextAlign.left,
              style: Theme.of(context).fixedFontStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _WhenColumn extends ColumnData<LogData> {
  _WhenColumn()
      : super(
          'When',
          fixedWidthPx: scaleByFontFactor(120),
        );

  @override
  bool get supportsSorting => false;

  @override
  String getValue(LogData dataObject) => dataObject.timestamp == null
      ? ''
      : timeFormat
          .format(DateTime.fromMillisecondsSinceEpoch(dataObject.timestamp!));
}

class _KindColumn extends ColumnData<LogData>
    implements ColumnRenderer<LogData> {
  _KindColumn()
      : super(
          'Kind',
          fixedWidthPx: scaleByFontFactor(155),
        );

  @override
  bool get supportsSorting => false;

  @override
  String getValue(LogData dataObject) => dataObject.kind;

  @override
  Widget build(
    BuildContext context,
    LogData item, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
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
    final textStyle = Theme.of(context).fixedFontStyle;

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

@visibleForTesting
class MessageColumn extends ColumnData<LogData>
    implements ColumnRenderer<LogData> {
  MessageColumn() : super.wide('Message');

  @override
  bool get supportsSorting => false;

  @override
  String? getValue(LogData dataObject) =>
      dataObject.summary ?? dataObject.details;

  @override
  int compare(LogData a, LogData b) {
    final String valueA = getValue(a)!;
    final String valueB = getValue(b)!;
    // Matches frame descriptions (e.g. '#12  11.4ms ')
    final regex = RegExp(r'#(\d+)\s+\d+.\d+ms\s*');
    final valueAIsFrameLog = valueA.startsWith(regex);
    final valueBIsFrameLog = valueB.startsWith(regex);
    if (valueAIsFrameLog && valueBIsFrameLog) {
      final frameNumberA = regex.firstMatch(valueA)![1]!;
      final frameNumberB = regex.firstMatch(valueB)![1]!;
      return int.parse(frameNumberA).compareTo(int.parse(frameNumberB));
    } else if (valueAIsFrameLog && !valueBIsFrameLog) {
      return -1;
    } else if (!valueAIsFrameLog && valueBIsFrameLog) {
      return 1;
    }
    return valueA.compareTo(valueB);
  }

  @override
  Widget build(
    BuildContext context,
    LogData data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    TextStyle textStyle = Theme.of(context).fixedFontStyle;
    if (isRowSelected) {
      textStyle = textStyle.copyWith(color: defaultSelectionForegroundColor);
    }

    if (data.kind == 'flutter.frame') {
      const Color color = Color.fromARGB(0xff, 0x00, 0x91, 0xea);
      final Text text = Text(
        getDisplayValue(data),
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );

      double frameLength = 0.0;
      try {
        final int micros = jsonDecode(data.details!)['elapsed'];
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
            textStyle,
          ),
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table/table.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../console.dart';
import '../screen.dart';
import '../split.dart';
import '../theme.dart';
import '../ui/filter.dart';
import '../ui/icons.dart';
import '../ui/search.dart';
import '../ui/service_extension_widgets.dart';
import 'delegate.dart';
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
  LogData selected;

  LoggingController controller;

  final ScrollController verticalScrollingController = ScrollController();
  LoggingTableDelegate delegate;

  @override
  void initState() {
    super.initState();
    ga.screen(LoggingScreen.id);
    delegate = LoggingTableDelegate(
      controller: verticalScrollingController,
      onRowSelected: (int row) {
        print(row);
      }
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    delegate.themeData = Theme.of(context);

    final newController = Provider.of<LoggingController>(context);
    if (newController == controller) return;
    controller = newController;

    cancel();

    delegate.logs = controller.filteredData.value;
    addAutoDisposeListener(controller.filteredData, () {
      setState(() {
        delegate.logs = controller.filteredData.value;
      });
    });

    selected = controller.selectedLog.value;
    addAutoDisposeListener(controller.selectedLog, () {
      setState(() {
        selected = controller.selectedLog.value;
      });
    });
  }

  @override
  void dispose() {
    verticalScrollingController.dispose();
    super.dispose();
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
    final hasData = controller.filteredData.value.isNotEmpty;
    return Row(
      children: [
        ClearButton(onPressed: controller.clear),
        const Spacer(),
        StructuredErrorsToggle(),
        const SizedBox(width: denseSpacing),
        // TODO(kenz): fix focus issue when state is refreshed
        Container(
          width: wideSearchTextWidth,
          height: defaultTextFieldHeight,
          child: buildSearchField(
            controller: controller,
            searchFieldKey: loggingSearchFieldKey,
            searchFieldEnabled: hasData,
            shouldRequestFocus: false,
            supportsNavigation: true,
          ),
        ),
        const SizedBox(width: denseSpacing),
        FilterButton(
          onPressed: _showFilterDialog,
          isFilterActive: delegate.logs.length != controller.data.length,
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
          child: RawTableScrollView(
            verticalController: verticalScrollingController,
            delegate: delegate,
          )
        ),
        LogDetails(log: selected),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        controller: controller,
        queryInstructions: LoggingScreenBody.filterQueryInstructions,
        queryFilterArguments: controller.filterArgs,
      ),
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
  String _lastDetails;
  ScrollController scrollController;

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
      await widget.log.compute();
      setState(() {});
    }
  }

  bool showSimple(LogData log) => log != null && !log.needsComputing;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _buildContent(context, widget.log),
    );
  }

  Widget _buildContent(BuildContext context, LogData log) {
    // TODO(#1370): Handle showing flutter errors in a structured manner.
    return Stack(
      children: [
        _buildSimpleLog(context, log),
        if (log != null && log.needsComputing)
          const CenteredCircularProgressIndicator(),
      ],
    );
  }

  Widget _buildSimpleLog(BuildContext context, LogData log) {
    final disabled = log?.details == null || log.details.isEmpty;

    final details = log?.details;
    if (details != _lastDetails) {
      if (scrollController.hasClients) {
        // Make sure we change the scroll if the log details shown have changed.
        scrollController.jumpTo(0);
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
              dataProvider: disabled ? null : () => log?.prettyPrinted,
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

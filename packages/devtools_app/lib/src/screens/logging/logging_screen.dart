// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics.dart' as ga;
import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import '../../shared/theme.dart';
import '../../ui/filter.dart';
import '../../ui/icons.dart';
import '../../ui/search.dart';
import '../../ui/service_extension_widgets.dart';
import '_log_details.dart';
import '_logs_table.dart';
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

  bool _controllerInitialized = false;

  late LoggingController _controller;

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
    if (_controllerInitialized && newController == _controller) return;
    _controller = newController;
    _controllerInitialized = true;

    cancelListeners();

    filteredLogs = _controller.filteredData.value;
    addAutoDisposeListener(_controller.filteredData, () {
      setState(() {
        filteredLogs = _controller.filteredData.value;
      });
    });

    selected = _controller.selectedLog.value;
    addAutoDisposeListener(_controller.selectedLog, () {
      setState(() {
        selected = _controller.selectedLog.value;
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
    final hasData = _controller.filteredData.value.isNotEmpty;
    return Row(
      children: [
        ClearButton(onPressed: _controller.clear),
        const Spacer(),
        StructuredErrorsToggle(),
        const SizedBox(width: denseSpacing),
        // TODO(kenz): fix focus issue when state is refreshed
        Container(
          width: wideSearchTextWidth,
          height: defaultTextFieldHeight,
          child: buildSearchField(
            controller: _controller,
            searchFieldKey: loggingSearchFieldKey,
            searchFieldEnabled: hasData,
            shouldRequestFocus: false,
            supportsNavigation: true,
          ),
        ),
        const SizedBox(width: denseSpacing),
        FilterButton(
          onPressed: _showFilterDialog,
          isFilterActive: filteredLogs.length != _controller.data.length,
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
            onItemSelected: _controller.selectLog,
            selectionNotifier: _controller.selectedLog,
            searchMatchesNotifier: _controller.searchMatches,
            activeSearchMatchNotifier: _controller.activeSearchMatch,
          ),
        ),
        LogDetails(log: selected),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog<LoggingController, LogData>(
        controller: _controller,
        queryInstructions: LoggingScreenBody.filterQueryInstructions,
        queryFilterArguments: _controller.filterArgs,
      ),
    );
  }
}

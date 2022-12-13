// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../service/service_extension_widgets.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/common_widgets.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import '../../shared/theme.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/icons.dart';
import '../../shared/ui/search.dart';
import '../../shared/utils.dart';
import '_log_details.dart';
import '_logs_table.dart';
import 'logging_controller.dart';

final loggingSearchFieldKey = GlobalKey(debugLabel: 'LoggingSearchFieldKey');

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  LoggingScreen()
      : super(
          id,
          title: ScreenMetaData.logging.title,
          icon: Octicons.clippy,
        );

  static final id = ScreenMetaData.logging.id;

  @override
  String get docPageId => screenId;

  @override
  Widget build(BuildContext context) => const LoggingScreenBody();

  @override
  Widget buildStatus(BuildContext context) {
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
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<LoggingController, LoggingScreenBody>,
        SearchFieldMixin<LoggingScreenBody> {
  late List<LogData> filteredLogs;

  @override
  void initState() {
    super.initState();
    ga.screen(LoggingScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();

    filteredLogs = controller.filteredData.value;
    addAutoDisposeListener(controller.filteredData, () {
      setState(() {
        filteredLogs = controller.filteredData.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildLoggingControls(),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: _buildLoggingBody(),
        ),
      ],
    );
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
          isFilterActive: filteredLogs.length != controller.data.length,
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
            selectionNotifier: controller.selectedLog,
            searchMatchesNotifier: controller.searchMatches,
            activeSearchMatchNotifier: controller.activeSearchMatch,
          ),
        ),
        ValueListenableBuilder<LogData?>(
          valueListenable: controller.selectedLog,
          builder: (context, selected, _) {
            return LogDetails(log: selected);
          },
        ),
      ],
    );
  }

  void _showFilterDialog() {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => FilterDialog<LoggingController, LogData>(
          controller: controller,
          queryInstructions: LoggingScreenBody.filterQueryInstructions,
          queryFilterArguments: controller.filterArgs,
        ),
      ),
    );
  }
}

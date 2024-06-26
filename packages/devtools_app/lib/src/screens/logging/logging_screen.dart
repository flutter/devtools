// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../service/service_extension_widgets.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/screen.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import '../../shared/utils.dart';
import '_log_details.dart';
import '_logs_table.dart';
import 'logging_controller.dart';
import 'shared/constants.dart';

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  LoggingScreen()
      : super(
          id,
          title: ScreenMetaData.logging.title,
          icon: ScreenMetaData.logging.icon,
        );

  static final id = ScreenMetaData.logging.id;

  @override
  String get docPageId => screenId;

  @override
  Widget buildScreenBody(BuildContext context) => const LoggingScreenBody();

  @override
  Widget buildStatus(BuildContext context) {
    final controller = Provider.of<LoggingController>(context);

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
  const LoggingScreenBody({super.key});

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
  State<LoggingScreenBody> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<LoggingController, LoggingScreenBody> {
  late List<LogData> filteredLogs;

  @override
  void initState() {
    super.initState();
    ga.screen(gac.logging);
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
        const SizedBox(height: intermediateSpacing),
        Expanded(
          child: _buildLoggingBody(),
        ),
      ],
    );
  }

  // TODO(kenz): replace with helper widget
  Widget _buildLoggingControls() {
    final hasData = controller.filteredData.value.isNotEmpty;
    return Row(
      children: [
        ClearButton(
          onPressed: controller.clear,
          gaScreen: gac.logging,
          gaSelection: gac.clear,
          minScreenWidthForTextBeforeScaling: loggingMinVerboseWidth,
        ),
        const Spacer(),
        const SizedBox(width: denseSpacing),
        // TODO(kenz): fix focus issue when state is refreshed
        SearchField<LoggingController>(
          searchFieldWidth: isScreenWiderThan(context, loggingMinVerboseWidth)
              ? wideSearchFieldWidth
              : defaultSearchFieldWidth,
          searchController: controller,
          searchFieldEnabled: hasData,
        ),
        const SizedBox(width: denseSpacing),
        DevToolsFilterButton(
          onPressed: _showFilterDialog,
          isFilterActive: controller.isFilterActive,
        ),
        const SizedBox(width: denseSpacing),
        CopyToClipboardControl(
          dataProvider: () => controller.filteredData.value
              .map((e) => '${e.timestamp} [${e.kind}] ${e.prettyPrinted()}')
              .joinWithTrailing('\n'),
          tooltip: 'Copy filtered logs',
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          gaScreen: gac.logging,
          gaSelection: gac.loggingSettings,
          tooltip: 'Logging Settings',
          onPressed: () {
            unawaited(
              showDialog(
                context: context,
                builder: (context) => const LoggingSettingsDialog(),
              ),
            );
          },
        ),
      ],
    );
  }

  // TODO(kenz): replace with helper widget.
  Widget _buildLoggingBody() {
    return SplitPane(
      axis: Axis.vertical,
      initialFractions: const [0.72, 0.28],
      // TODO(kenz): refactor so that the LogDetails header can be the splitter.
      // This would be more consistent with other screens that use the console
      // header as the splitter.
      children: [
        RoundedOutlinedBorder(
          clip: true,
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
        builder: (context) => FilterDialog<LogData>(
          controller: controller,
          queryInstructions: LoggingScreenBody.filterQueryInstructions,
        ),
      ),
    );
  }
}

class LoggingSettingsDialog extends StatelessWidget {
  const LoggingSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: const DialogTitleText('Logging Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...dialogSubHeader(
            theme,
            'General',
          ),
          const StructuredErrorsToggle(),
        ],
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}

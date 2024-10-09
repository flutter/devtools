// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/screen.dart';
import '../../shared/utils.dart';
import '_log_details.dart';
import '_logs_table.dart';
import 'logging_controller.dart';
import 'logging_controls.dart';

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  LoggingScreen() : super.fromMetaData(ScreenMetaData.logging);

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

  @override
  State<LoggingScreenBody> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<LoggingController, LoggingScreenBody> {
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
    addAutoDisposeListener(controller.filteredData);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LoggingControls(),
        const SizedBox(height: intermediateSpacing),
        Expanded(
          child: _buildLoggingBody(),
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
            data: controller.filteredData.value,
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
}

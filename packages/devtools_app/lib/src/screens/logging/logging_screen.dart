// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../../shared/ui/utils.dart';
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
    final controller = screenControllers.lookup<LoggingController>();
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
    with AutoDisposeMixin {
  late LoggingController controller;

  @override
  void initState() {
    super.initState();
    ga.screen(gac.logging);
    controller = screenControllers.lookup<LoggingController>();
    addAutoDisposeListener(controller.filteredData);
  }

  @override
  Widget build(BuildContext context) {
    final splitAxis = _splitAxisFor(context);
    return Column(
      children: [
        const LoggingControls(),
        const SizedBox(height: intermediateSpacing),
        Expanded(
          child: SplitPane(
            axis: splitAxis,
            initialFractions:
                splitAxis == Axis.vertical
                    ? const [0.8, 0.2]
                    : const [0.7, 0.3],
            children: [
              RoundedOutlinedBorder(
                clip: true,
                child: LogsTable(
                  controller: controller,
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
          ),
        ),
      ],
    );
  }

  Axis _splitAxisFor(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final aspectRatio = screenSize.width / screenSize.height;
    if (screenSize.height <= MediaSize.s.heightThreshold ||
        aspectRatio >= 1.2) {
      return Axis.horizontal;
    }
    return Axis.vertical;
  }
}

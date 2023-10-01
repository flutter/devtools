// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import 'controller.dart';
import 'primitives/analysis_status.dart';
import 'primitives/simple_items.dart';
import 'widgets/simple_widgets.dart';

// TODO(polina-c): review UX with UX specialists
// https://github.com/flutter/devtools/issues/3951
class LeaksPane extends StatefulWidget {
  const LeaksPane({Key? key}) : super(key: key);

  @override
  State<LeaksPane> createState() => _LeaksPaneState();
}

class _LeaksPaneState extends State<LeaksPane> {
  late LeaksPaneController _leaksController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _leaksController = LeaksPaneController();
  }

  @override
  void dispose() {
    _leaksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(densePadding),
      child: ValueListenableBuilder<AppStatus>(
        valueListenable: _leaksController.appStatus,
        builder: (_, appStatus, __) {
          if (appStatus != AppStatus.leaksFound) {
            return Column(
              children: [
                const LeaksHelpLink(),
                Text(_leaksController.appStatusMessage()),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnalysisStatusView(
                controller: _leaksController.analysisStatus,
                analysisStarter: Row(
                  children: [
                    AnalyzeButton(leaksController: _leaksController),
                    const LeaksHelpLink(),
                  ],
                ),
              ),
              const SizedBox(height: denseSpacing),
              Expanded(
                child: SingleChildScrollView(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _leaksController.leakSummaryHistory,
                    builder: (_, value, __) => Text(value),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

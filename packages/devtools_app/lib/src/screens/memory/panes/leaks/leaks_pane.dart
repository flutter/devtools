// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/theme.dart';
import '../../primitives/ui.dart';
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
    return ValueListenableBuilder<AppStatus>(
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
              controller: _leaksController.analysisAtatus,
              analysisStarter: Row(
                children: [
                  AnalyzeButton(leaksController: _leaksController),
                  const SizedBox(width: denseSpacing),
                  _ForceGCButton(leaksController: _leaksController),
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
    );
  }
}

class _ForceGCButton extends StatelessWidget {
  const _ForceGCButton({Key? key, required this.leaksController})
      : super(key: key);

  final LeaksPaneController leaksController;

  @override
  Widget build(BuildContext context) {
    return IconLabelButton(
      label: 'Force GC',
      icon: Icons.delete,
      tooltip: 'Force full GC in the application\n'
          'to make sure to collect everything that can be collected.',
      onPressed: () async => await leaksController.forceGC(),
      minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
    );
  }
}

// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../controller.dart';
import '../diagnostics/formatter.dart';

class LeaksHelpLink extends StatelessWidget {
  const LeaksHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = 'leaks';

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: gac.memory,
      gaSelection: gac.topicDocumentationButton(_documentationTopic),
      dialogTitle: 'Memory Leak Detection Help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Use the memory leak detection tab to detect\n'
              'and troubleshoot some types of memory leaks.'),
          MoreInfoLink(
            url: linkToGuidance,
            gaScreenName: gac.memory,
            gaSelectedItemDescription:
                gac.topicDocumentationLink(_documentationTopic),
          ),
        ],
      ),
    );
  }
}

class AnalyzeButton extends StatelessWidget {
  const AnalyzeButton({Key? key, required this.leaksController})
      : super(key: key);

  final LeaksPaneController leaksController;

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton(
      label: 'Analyze and Download',
      icon: Icons.file_download,
      tooltip: 'Analyze the leaks and download the result\n'
          'to ${yamlFilePrefix}_<time>.yaml.',
      onPressed: () async => await leaksController.requestLeaksAndSaveToYaml(),
      gaScreen: gac.memory,
      gaSelection: gac.MemoryEvent.leaksAnalyze,
      minScreenWidthForTextBeforeScaling: memoryControlsMinVerboseWidth,
    );
  }
}

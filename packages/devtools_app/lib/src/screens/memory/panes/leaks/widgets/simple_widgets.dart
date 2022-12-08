// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart' as analytics_constants;
import '../../../../../shared/common_widgets.dart';
import '../../../primitives/ui.dart';
import '../controller.dart';
import '../diagnostics/formatter.dart';

class LeaksHelpLink extends StatelessWidget {
  const LeaksHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = 'leaks';

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: analytics_constants.memory,
      gaSelection:
          analytics_constants.topicDocumentationButton(_documentationTopic),
      dialogTitle: 'Memory Leak Detection Help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Use the memory leak detection tab to detect\n'
              'and troubleshoot some types of memory leaks.'),
          MoreInfoLink(
            url: linkToGuidance,
            gaScreenName: analytics_constants.memory,
            gaSelectedItemDescription:
                analytics_constants.topicDocumentationLink(_documentationTopic),
          )
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
    return IconLabelButton(
      label: 'Analyze and Download',
      icon: Icons.file_download,
      tooltip: 'Analyze the leaks and download the result\n'
          'to ${yamlFilePrefix}_<time>.yaml.',
      onPressed: () async => await leaksController.requestLeaksAndSaveToYaml(),
      minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
    );
  }
}

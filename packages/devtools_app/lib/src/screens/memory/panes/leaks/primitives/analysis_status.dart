// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/primitives/utils.dart';

enum AnalysisStatus {
  notStarted,
  ongoing,

  /// The process is complete and we want user to see the result.
  showingResult,

  /// The process is complete and we want user to acknowledge the error.
  showingError,
}

const Duration _showingResultDelay = Duration(seconds: 5);

/// Describes status of the ongoing process.
class AnalysisStatusController {
  AnalysisStatusController() {
    status.addListener(_statusChanged);
  }

  ValueNotifier<AnalysisStatus> status =
      ValueNotifier<AnalysisStatus>(AnalysisStatus.notStarted);

  ValueNotifier<String> message = ValueNotifier('');

  void reset() {
    status.value = AnalysisStatus.notStarted;
    message.value = '';
  }

  void _statusChanged() async {
    if (status.value == AnalysisStatus.showingResult) {
      await Future.delayed(_showingResultDelay);
      reset();
    }
  }

  void dispose() {
    status.dispose();
    message.dispose();
  }
}

/// Shows [analysisStarter] if the analysis is not started yet and the status
/// of the process otherwise.
///
/// If process is completed successfully, keeps the status for
/// [_showingResultDelay] and then shows [analysisStarter].
/// If the process ended up with error, show the error and two buttons
/// (Copy ans OK). After user clicks [OK], shows [analysisStarter].
class AnalysisStatusView extends StatelessWidget {
  const AnalysisStatusView({
    Key? key,
    required this.controller,
    required this.analysisStarter,
  }) : super(key: key);
  final AnalysisStatusController controller;
  final Widget analysisStarter;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [
        controller.status,
        controller.message,
      ],
      builder: (_, values, __) {
        final status = values.first as AnalysisStatus;
        final message = values.second as String;
        if (status == AnalysisStatus.notStarted) {
          return analysisStarter;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(denseSpacing),
              child: Text(message),
            ),
            if (status == AnalysisStatus.showingError)
              Row(
                children: [
                  CopyToClipboardControl(dataProvider: () => message),
                  MaterialButton(
                    child: const Text('OK'),
                    onPressed: () => controller.reset(),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

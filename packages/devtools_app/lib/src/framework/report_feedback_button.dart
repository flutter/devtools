// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import '../shared/utils.dart';

/// Button that, when clicked, will open the DevTools issue tracker in the
/// browser.
class ReportFeedbackButton extends ScaffoldAction {
  ReportFeedbackButton({super.key, super.color})
      : super(
          icon: Icons.bug_report_outlined,
          tooltip: 'Report feedback',
          onPressed: (_) {
            ga.select(
              gac.devToolsMain,
              gac.feedbackButton,
            );
            unawaited(
              launchUrlWithErrorHandling(
                devToolsExtensionPoints.issueTrackerLink().url,
              ),
            );
          },
        );
}

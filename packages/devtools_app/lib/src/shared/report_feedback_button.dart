// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../config_specific/launch_url/launch_url.dart';
import 'common_widgets.dart';
import 'globals.dart';
import 'scaffold.dart';
import 'theme.dart';

class ReportFeedbackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: 'Report feedback',
      InkWell(
        onTap: () async {
          ga.select(
            analytics_constants.devToolsMain,
            analytics_constants.feedbackButton,
          );
          await launchUrl(
            devToolsExtensionPoints.issueTrackerLink().url,
            context,
          );
        },
        Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          Icon(
            Icons.bug_report,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

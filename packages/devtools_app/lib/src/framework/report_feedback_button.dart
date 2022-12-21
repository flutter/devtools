// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/config_specific/launch_url/launch_url.dart';
import '../shared/globals.dart';
import '../shared/theme.dart';

class ReportFeedbackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: 'Report feedback',
      child: InkWell(
        onTap: () async {
          ga.select(
            gac.devToolsMain,
            gac.feedbackButton,
          );
          await launchUrl(
            devToolsExtensionPoints.issueTrackerLink().url,
            context,
          );
        },
        child: Container(
          width: actionWidgetSize,
          height: actionWidgetSize,
          alignment: Alignment.center,
          child: Icon(
            Icons.bug_report,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

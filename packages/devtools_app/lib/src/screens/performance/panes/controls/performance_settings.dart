// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/dialogs.dart';
import '../../../../shared/feature_flags.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../performance_controller.dart';

class PerformanceSettingsDialog extends StatelessWidget {
  const PerformanceSettingsDialog(this.controller);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: dialogTitleText(theme, 'Performance Settings'),
      includeDivider: false,
      content: Container(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TimelineStreamSettings(controller: controller),
            if (serviceManager.connectedApp!.isFlutterAppNow!) ...[
              const SizedBox(height: denseSpacing),
              FlutterSettings(controller: controller),
            ],
          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}

class TimelineStreamSettings extends StatelessWidget {
  const TimelineStreamSettings({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...dialogSubHeader(theme, 'Recorded Timeline Streams'),
        ..._defaultRecordedStreams(theme),
        ..._advancedStreams(theme),
      ],
    );
  }

  List<Widget> _defaultRecordedStreams(ThemeData theme) {
    return [
      RichText(
        text: TextSpan(
          text: 'Default',
          style: theme.subtleTextStyle,
        ),
      ),
      ..._timelineStreams(theme, advanced: false),
      // Special case "Network Traffic" because it is not implemented as a
      // Timeline recorded stream in the VM. The user does not need to be aware of
      // the distinction, however.
      CheckboxSetting(
        title: 'Network',
        description: 'Http traffic',
        notifier: controller.httpTimelineLoggingEnabled as ValueNotifier<bool?>,
        onChanged: (value) =>
            controller.toggleHttpRequestLogging(value ?? false),
      ),
    ];
  }

  List<Widget> _advancedStreams(ThemeData theme) {
    return [
      RichText(
        text: TextSpan(
          text: 'Advanced',
          style: theme.subtleTextStyle,
        ),
      ),
      ..._timelineStreams(theme, advanced: true),
    ];
  }

  List<Widget> _timelineStreams(
    ThemeData theme, {
    required bool advanced,
  }) {
    final streams = advanced
        ? serviceManager.timelineStreamManager.advancedStreams
        : serviceManager.timelineStreamManager.basicStreams;
    final settings = streams
        .map(
          (stream) => CheckboxSetting(
            title: stream.name,
            description: stream.description,
            notifier: stream.recorded as ValueNotifier<bool?>,
            onChanged: (newValue) =>
                serviceManager.timelineStreamManager.updateTimelineStream(
              stream,
              newValue ?? false,
            ),
          ),
        )
        .toList();
    return settings;
  }
}

class FlutterSettings extends StatelessWidget {
  const FlutterSettings({Key? key, required this.controller}) : super(key: key);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...dialogSubHeader(Theme.of(context), 'Additional Settings'),
        CheckboxSetting(
          notifier: controller.badgeTabForJankyFrames as ValueNotifier<bool?>,
          title: 'Badge Performance tab when Flutter UI jank is detected',
        ),
        if (FeatureFlags.embeddedPerfetto)
          CheckboxSetting(
            notifier: controller.useLegacyTraceViewer,
            title: 'Use legacy trace viewer',
            onChanged: controller.toggleUseLegacyTraceViewer,
          ),
      ],
    );
  }
}

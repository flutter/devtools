// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/charts/flame_chart.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/dialogs.dart';
import '../../../../shared/feature_flags.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/ui/search.dart';
import 'legacy/legacy_events_controller.dart';
import 'legacy/timeline_flame_chart.dart';
import 'perfetto/perfetto.dart';
import 'timeline_events_controller.dart';

class TimelineEventsTabView extends StatelessWidget {
  const TimelineEventsTabView({super.key, required this.controller});

  final TimelineEventsController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.useLegacyTraceViewer,
      builder: (context, useLegacy, _) {
        return useLegacy
            ? KeepAliveWrapper(
                child:
                    DualValueListenableBuilder<EventsControllerStatus, double>(
                  firstListenable: controller.status,
                  secondListenable:
                      controller.legacyController.processor.progressNotifier,
                  builder: (context, status, processingProgress, _) {
                    return TimelineEventsView(
                      controller: controller,
                      processing: status == EventsControllerStatus.processing,
                      processingProgress: processingProgress,
                    );
                  },
                ),
              )
            : KeepAliveWrapper(
                child: EmbeddedPerfetto(
                  perfettoController: controller.perfettoController,
                ),
              );
      },
    );
  }
}

class TimelineEventsTabControls extends StatelessWidget {
  const TimelineEventsTabControls({super.key, required this.controller});

  final TimelineEventsController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.useLegacyTraceViewer,
      builder: (context, useLegacy, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (useLegacy || !FeatureFlags.embeddedPerfetto) ...[
              ValueListenableBuilder<EventsControllerStatus>(
                valueListenable: controller.status,
                builder: (context, status, _) {
                  final searchFieldEnabled =
                      status == EventsControllerStatus.ready;
                  return SearchField<LegacyTimelineEventsController>(
                    searchController: controller.legacyController,
                    searchFieldEnabled: searchFieldEnabled,
                    searchFieldWidth: wideSearchFieldWidth,
                  );
                },
              ),
              const SizedBox(width: denseSpacing),
              FlameChartHelpButton(
                gaScreen: gac.performance,
                gaSelection: gac.timelineFlameChartHelp,
              ),
            ],
            if (!offlineController.offlineMode.value) ...[
              // TODO(kenz): add a switch to enable the CPU profiler once the
              // tracing format supports it (when we switch to protozero).
              const SizedBox(width: denseSpacing),
              TraceCategoriesButton(controller: controller),
              const SizedBox(width: denseSpacing),
              RefreshTimelineEventsButton(controller: controller),
            ],
          ],
        );
      },
    );
  }
}

class TraceCategoriesButton extends StatelessWidget {
  const TraceCategoriesButton({
    required this.controller,
    super.key,
  });

  final TimelineEventsController controller;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton.iconOnly(
      icon: Icons.checklist,
      outlined: false,
      tooltip: 'Trace categories',
      gaScreen: gac.performance,
      gaSelection: gac.traceCategories,
      onPressed: () => _openTraceCategoriesDialog(context),
    );
  }

  void _openTraceCategoriesDialog(BuildContext context) {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => TraceCategoriesDialog(controller),
      ),
    );
  }
}

class RefreshTimelineEventsButton extends StatelessWidget {
  const RefreshTimelineEventsButton({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TimelineEventsController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EventsControllerStatus>(
      valueListenable: controller.status,
      builder: (context, status, _) {
        return RefreshButton(
          iconOnly: true,
          outlined: false,
          onPressed: status == EventsControllerStatus.processing
              ? null
              : controller.processAllTraceEvents,
          tooltip: 'Refresh timeline events',
          gaScreen: gac.performance,
          gaSelection: gac.refreshTimelineEvents,
        );
      },
    );
  }
}

class TraceCategoriesDialog extends StatelessWidget {
  const TraceCategoriesDialog(this.timelineEventsController);

  final TimelineEventsController timelineEventsController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: const DialogTitleText('Trace Categories'),
      includeDivider: false,
      content: Container(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._defaultRecordedStreams(theme),
            const SizedBox(height: denseSpacing),
            ..._advancedStreams(theme),
          ],
        ),
      ),
      actions: const [
        DialogCloseButton(),
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
      ..._timelineStreams(advanced: false),
      // Special case "Network Traffic" because it is not implemented as a
      // Timeline recorded stream in the VM. The user does not need to be aware of
      // the distinction, however.
      CheckboxSetting(
        title: 'Network',
        description: 'Http traffic',
        notifier: timelineEventsController.httpTimelineLoggingEnabled
            as ValueNotifier<bool?>,
        onChanged: (value) => unawaited(
          timelineEventsController.toggleHttpRequestLogging(value ?? false),
        ),
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
      ..._timelineStreams(advanced: true),
    ];
  }

  List<Widget> _timelineStreams({
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
            onChanged: (newValue) => unawaited(
              serviceManager.timelineStreamManager.updateTimelineStream(
                stream,
                newValue ?? false,
              ),
            ),
          ),
        )
        .toList();
    return settings;
  }
}

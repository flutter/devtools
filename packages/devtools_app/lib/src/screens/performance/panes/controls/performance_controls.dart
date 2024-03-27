// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../service/service_extension_widgets.dart';
import '../../../../service/service_extensions.dart' as extensions;
import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/file_import.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/screen.dart';
import '../../panes/timeline_events/timeline_events_controller.dart';
import '../../performance_controller.dart';
import 'enhance_tracing/enhance_tracing.dart';
import 'more_debugging_options.dart';
import 'performance_settings.dart';

class PerformanceControls extends StatelessWidget {
  const PerformanceControls({
    super.key,
    required this.controller,
    required this.onClear,
  });

  static const minScreenWidthForTextBeforeScaling = 1085.0;

  final PerformanceController controller;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return OfflineAwareControls(
      gaScreen: gac.performance,
      controlsBuilder: (offline) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<EventsControllerStatus>(
              valueListenable: controller.timelineEventsController.status,
              builder: (context, status, _) {
                return _PrimaryControls(
                  controller: controller,
                  processing: status == EventsControllerStatus.refreshing,
                  offline: offline,
                  onClear: onClear,
                );
              },
            ),
            if (!offline)
              Padding(
                padding: const EdgeInsets.only(left: defaultSpacing),
                child: _SecondaryPerformanceControls(controller: controller),
              ),
          ],
        );
      },
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    Key? key,
    required this.controller,
    required this.processing,
    required this.offline,
    required this.onClear,
  }) : super(key: key);

  final PerformanceController controller;

  final bool processing;

  final bool offline;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (serviceConnection
            .serviceManager.connectedApp!.isFlutterAppNow!) ...[
          VisibilityButton(
            show: preferences.performance.showFlutterFramesChart,
            gaScreen: gac.performance,
            onPressed:
                controller.flutterFramesController.toggleShowFlutterFrames,
            label: 'Flutter frames',
            tooltip: 'Toggle visibility of the Flutter frames chart',
          ),
          const SizedBox(width: denseSpacing),
        ],
        if (!offline)
          GaDevToolsButton(
            icon: Icons.block,
            label: 'Clear all',
            gaScreen: gac.performance,
            gaSelection: gac.clear,
            tooltip: 'Clear all data on the Performance screen',
            minScreenWidthForTextBeforeScaling:
                PerformanceControls.minScreenWidthForTextBeforeScaling,
            onPressed: processing ? null : _clearPerformanceData,
          ),
      ],
    );
  }

  Future<void> _clearPerformanceData() async {
    ga.select(gac.performance, gac.clear);
    await controller.clearData();
    onClear();
  }
}

class _SecondaryPerformanceControls extends StatelessWidget {
  const _SecondaryPerformanceControls({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (serviceConnection
            .serviceManager.connectedApp!.isFlutterAppNow!) ...[
          ServiceExtensionButtonGroup(
            minScreenWidthForTextBeforeScaling:
                PerformanceControls.minScreenWidthForTextBeforeScaling,
            extensions: [
              extensions.performanceOverlay,
            ],
          ),
          const SizedBox(width: denseSpacing),
          EnhanceTracingButton(controller.enhanceTracingController),
          const SizedBox(width: denseSpacing),
          const MoreDebuggingOptionsButton(),
        ],
        const SizedBox(width: denseSpacing),
        OpenSaveButtonGroup(
          screenId: ScreenMetaData.performance.id,
          onSave: controller.exportData,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          gaScreen: gac.performance,
          gaSelection: gac.PerformanceEvents.performanceSettings.name,
          onPressed: () => _openSettingsDialog(context),
        ),
      ],
    );
  }

  void _openSettingsDialog(BuildContext context) {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => PerformanceSettingsDialog(controller),
      ),
    );
  }
}

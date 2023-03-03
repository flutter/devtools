// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../service/service_extension_widgets.dart';
import '../../../../service/service_extensions.dart' as extensions;
import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../panes/timeline_events/timeline_events_controller.dart';
import '../../performance_controller.dart';
import 'enhance_tracing/enhance_tracing.dart';
import 'more_debugging_options.dart';
import 'performance_settings.dart';

class PerformanceControls extends StatelessWidget {
  const PerformanceControls({
    required this.controller,
    required this.onClear,
  });

  static const minScreenWidthForTextBeforeScaling = 920.0;

  final PerformanceController controller;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return OfflineAwareControls(
      controlsBuilder: (offline) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<EventsControllerStatus>(
              valueListenable: controller.timelineEventsController.status,
              builder: (context, status, _) {
                return _PrimaryControls(
                  controller: controller,
                  processing: status == EventsControllerStatus.processing,
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
        if (serviceManager.connectedApp!.isFlutterAppNow!) ...[
          VisibilityButton(
            show: preferences.performance.showFlutterFramesChart,
            onPressed:
                controller.flutterFramesController.toggleShowFlutterFrames,
            label: 'Flutter frames',
            tooltip: 'Toggle visibility of the Flutter frames chart',
          ),
          const SizedBox(width: denseSpacing),
        ],
        if (!offline)
          OutlinedIconButton(
            icon: Icons.block,
            tooltip: 'Clear all data on the Performance screen',
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
        if (serviceManager.connectedApp!.isFlutterAppNow!) ...[
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
        const SizedBox(width: defaultSpacing),
        OutlinedIconButton(
          icon: Icons.file_download,
          tooltip: 'Export data',
          onPressed: _exportPerformanceData,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: () => _openSettingsDialog(context),
        ),
      ],
    );
  }

  void _exportPerformanceData() {
    ga.select(gac.performance, gac.export);
    controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
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

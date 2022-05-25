// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../analytics/analytics.dart' as ga;
import '../../../analytics/constants.dart' as analytics_constants;
import '../../../primitives/auto_dispose_mixin.dart';
import '../../../shared/common_widgets.dart';
import '../../../shared/notifications.dart';
import '../../../shared/theme.dart';
import '../memory_android_chart.dart' as android;
import '../memory_charts.dart';
import '../memory_controller.dart';
import '../memory_events_pane.dart' as events;
import '../memory_vm_chart.dart' as vm;
import '../primitives/painting.dart';
import 'constants.dart';
import 'controls_widgets.dart';
import 'memory_config.dart';

class MemoryControls extends StatefulWidget {
  const MemoryControls({
    Key? key,
    required this.chartControllers,
  }) : super(key: key);

  final ChartControllers chartControllers;

  @override
  State<MemoryControls> createState() => _MemoryControlsState();
}

class _MemoryControlsState extends State<MemoryControls> with AutoDisposeMixin {
  /// Updated when the MemoryController's _androidCollectionEnabled ValueNotifier changes.
  bool _isAndroidCollection = MemoryController.androidADBDefault;
  bool _isAdvancedSettingsEnabled = false;

  bool controllersInitialized = false;
  late MemoryController _controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ChartControls(chartControllers: widget.chartControllers),
        const Spacer(),
        CommonControls(
            chartControllers: widget.chartControllers,
            isAndroidCollection: _isAndroidCollection,
            isAdvancedSettingsEnabled: _isAdvancedSettingsEnabled)
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<MemoryController>(context);
    if (!controllersInitialized || newController != _controller) {
      controllersInitialized = true;
      _controller = newController;
    }

    addAutoDisposeListener(_controller.androidCollectionEnabled, () {
      _isAndroidCollection = _controller.androidCollectionEnabled.value;
      setState(() {
        if (!_isAndroidCollection && _controller.isAndroidChartVisible) {
          // If we're no longer collecting android stats then hide the
          // chart and disable the Android Memory button.
          _controller.toggleAndroidChartVisibility();
        }
      });
    });

    addAutoDisposeListener(_controller.advancedSettingsEnabled, () {
      _isAdvancedSettingsEnabled = _controller.advancedSettingsEnabled.value;
      setState(() {
        if (!_isAdvancedSettingsEnabled &&
            _controller.isAdvancedSettingsVisible) {
          _controller.toggleAdvancedSettingsVisibility();
        }
      });
    });
  }
}

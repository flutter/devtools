// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../primitives/auto_dispose_mixin.dart';
import '../../memory_controller.dart';
import 'left_controls.dart';
import 'right_controls.dart';

class MemoryControlPane extends StatefulWidget {
  const MemoryControlPane({
    Key? key,
    required this.chartControllers,
  }) : super(key: key);

  final ChartControllers chartControllers;

  @override
  State<MemoryControlPane> createState() => _MemoryControlPaneState();
}

class _MemoryControlPaneState extends State<MemoryControlPane>
    with AutoDisposeMixin {
  /// Updated when the MemoryController's _androidCollectionEnabled ValueNotifier changes.
  bool _isAndroidCollection = MemoryController.androidADBDefault;
  bool _isAdvancedSettingsEnabled = false;

  bool controllersInitialized = false;
  late MemoryController _controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        LeftControls(chartControllers: widget.chartControllers),
        const Spacer(),
        RightControls(
          chartControllers: widget.chartControllers,
          isAndroidCollection: _isAndroidCollection,
          isAdvancedSettingsEnabled: _isAdvancedSettingsEnabled,
        )
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

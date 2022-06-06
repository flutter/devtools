// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';
import 'primary_controls.dart';
import 'secondary_controls.dart';

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
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, MemoryControlPane> {
  /// Updated when the MemoryController's _androidCollectionEnabled ValueNotifier changes.
  bool _isAndroidCollection = MemoryController.androidADBDefault;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PrimaryControls(chartControllers: widget.chartControllers),
        const Spacer(),
        SecondaryControls(
          chartControllers: widget.chartControllers,
          isAndroidCollection: _isAndroidCollection,
        )
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    // TODO(polinach): do we need this listener?
    // https://github.com/flutter/devtools/pull/4136#discussion_r881773861
    addAutoDisposeListener(controller.androidCollectionEnabled, () {
      _isAndroidCollection = controller.androidCollectionEnabled.value;
      setState(() {
        if (!_isAndroidCollection && controller.isAndroidChartVisible) {
          // If we're no longer collecting android stats then hide the
          // chart and disable the Android Memory button.
          controller.toggleAndroidChartVisibility();
        }
      });
    });
  }
}

// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';

class ToggleAdbMemoryButton extends StatefulWidget {
  const ToggleAdbMemoryButton({
    Key? key,
    required this.isAndroidCollection,
  }) : super(key: key);
  final bool isAndroidCollection;

  @override
  State<ToggleAdbMemoryButton> createState() => _ToggleAdbMemoryButtonState();
}

class _ToggleAdbMemoryButtonState extends State<ToggleAdbMemoryButton>
    with ProvidedControllerMixin<MemoryController, ToggleAdbMemoryButton> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  Widget build(BuildContext context) {
    return IconLabelButton(
      icon: controller.isAndroidChartVisible ? Icons.close : Icons.show_chart,
      label: 'Android Memory',
      onPressed: widget.isAndroidCollection
          ? controller.toggleAndroidChartVisibility
          : null,
      minScreenWidthForTextBeforeScaling: 900,
    );
  }
}

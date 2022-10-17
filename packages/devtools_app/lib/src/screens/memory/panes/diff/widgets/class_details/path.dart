// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../../shared/common_widgets.dart';
import '../../../../../../shared/theme.dart';
import '../../../../shared/heap/model.dart';
import '../../controller/simple_controllers.dart';

class RetainingPathView extends StatelessWidget {
  const RetainingPathView({
    super.key,
    required this.path,
    required this.controller,
  });

  final ClassOnlyHeapPath path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: denseRowSpacing),
        _PathControlPane(
          controller: controller,
          path: path,
        ),
        Expanded(child: _PathView(path: path, controller: controller)),
      ],
    );
  }
}

class _PathControlPane extends StatelessWidget {
  const _PathControlPane({required this.controller, required this.path});

  final ClassOnlyHeapPath path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CopyToClipboardControl(
          dataProvider: () => path.asLongString(),
          successMessage: null,
        ),
        const SizedBox(width: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.hideStandard,
          builder: (_, hideStandard, __) => FilterButton(
            onPressed: () =>
                controller.hideStandard.value = !controller.hideStandard.value,
            isFilterActive: hideStandard,
          ),
        ),
        const SizedBox(width: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.invert,
          builder: (_, invert, __) => ToggleButton(
            onPressed: () => controller.invert.value = !controller.invert.value,
            isSelected: invert,
            message: 'Invert the path',
            icon: Icons.swap_vert,
          ),
        ),
      ],
    );
  }
}

class _PathView extends StatelessWidget {
  const _PathView({required this.path, required this.controller});

  final ClassOnlyHeapPath path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Text(
          path.asLongString(delimiter: '\n→'),
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }
}

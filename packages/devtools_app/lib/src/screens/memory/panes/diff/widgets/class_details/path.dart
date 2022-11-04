// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../../shared/common_widgets.dart';
import '../../../../../../shared/theme.dart';
import '../../../../shared/heap/model.dart';
import '../../controller/simple_controllers.dart';
import '../../../../../../analytics/analytics.dart' as ga;
import '../../../../../../analytics/constants.dart' as analytics_constants;

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
        const SizedBox(height: densePadding),
        _PathControlPane(
          controller: controller,
          path: path,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: densePadding,
              left: densePadding,
            ),
            child: _PathView(path: path, controller: controller),
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.only(right: denseSpacing),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Retaining path for ${path.classes.last.className}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: denseSpacing),
          CopyToClipboardControl(
            dataProvider: () => path.toLongString(delimiter: '\n'),
            // We do not give success message because it pops up directly on
            // top of the path widget, that makes the widget anavailable
            // while message is here.
            successMessage: null,
            gaScreen: analytics_constants.memory,
            gaItem: analytics_constants.MemoryEvent.diffPathCopy,
          ),
          const SizedBox(width: denseSpacing),
          ValueListenableBuilder<bool>(
            valueListenable: controller.hideStandard,
            builder: (_, hideStandard, __) => FilterButton(
              onPressed: () {
                ga.select(
                  analytics_constants.memory,
                  '${analytics_constants.MemoryEvent.diffPathFilter}-$hideStandard',
                );
                controller.hideStandard.value = !controller.hideStandard.value;
              },
              isFilterActive: hideStandard,
              message: 'Hide standard libraries',
            ),
          ),
          const SizedBox(width: denseSpacing),
          ValueListenableBuilder<bool>(
            valueListenable: controller.invert,
            builder: (_, invert, __) => ToggleButton(
              onPressed: () {
                ga.select(
                  analytics_constants.memory,
                  '${analytics_constants.MemoryEvent.diffPathInvert}-$invert',
                );
                controller.invert.value = !controller.invert.value;
              },
              isSelected: invert,
              message: 'Invert the path',
              icon: Icons.swap_horiz,
            ),
          ),
        ],
      ),
    );
  }
}

class _PathView extends StatelessWidget {
  const _PathView({required this.path, required this.controller});

  final ClassOnlyHeapPath path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder<bool, bool>(
      firstListenable: controller.hideStandard,
      secondListenable: controller.invert,
      builder: (_, hideStandard, invert, __) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Text(
            path.toLongString(inverted: invert, hideStandard: hideStandard),
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}

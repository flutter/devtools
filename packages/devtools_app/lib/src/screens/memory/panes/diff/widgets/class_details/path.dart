// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../../shared/common_widgets.dart';
import '../../../../../../shared/memory/class_name.dart';
import '../../../../../../shared/memory/retaining_path.dart';
import '../../../../../../shared/primitives/utils.dart';
import '../../controller/class_data.dart';

class RetainingPathView extends StatelessWidget {
  const RetainingPathView({
    super.key,
    required this.path,
    required this.controller,
    required this.className,
  });

  final HeapClassName className;
  final PathFromRoot path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: densePadding),
          _PathControlPane(
            className: className,
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
      ),
    );
  }
}

class _PathControlPane extends StatelessWidget {
  const _PathControlPane({
    required this.controller,
    required this.path,
    required this.className,
  });

  final HeapClassName className;
  final PathFromRoot path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    final titleText = 'Retaining path for $className';
    return Row(
      children: [
        Expanded(
          child: DevToolsTooltip(
            message: titleText,
            child: Text(
              titleText,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: denseSpacing),
        CopyToClipboardControl(
          dataProvider: () => path.toLongString(delimiter: '\n'),
          // We do not give success message because it pops up directly on
          // top of the path widget, that makes the widget unavailable
          // while message is here.
          successMessage: null,
          gaScreen: gac.memory,
          gaItem: gac.MemoryEvent.diffPathCopy,
        ),
        const SizedBox(width: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.hideStandard,
          builder: (_, hideStandard, __) => DevToolsFilterButton(
            onPressed: () {
              ga.select(
                gac.memory,
                '${gac.MemoryEvent.diffPathFilter}-$hideStandard',
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
          builder: (_, invert, __) => DevToolsToggleButton(
            onPressed: () {
              ga.select(
                gac.memory,
                '${gac.MemoryEvent.diffPathInvert}-$invert',
              );
              controller.invert.value = !controller.invert.value;
            },
            isSelected: invert,
            message: 'Invert the path',
            icon: Icons.swap_horiz,
          ),
        ),
      ],
    );
  }
}

class _PathView extends StatelessWidget {
  const _PathView({required this.path, required this.controller});

  final PathFromRoot path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [
        controller.hideStandard,
        controller.invert,
      ],
      builder: (_, values, __) {
        final hideStandard = values.first as bool;
        final invert = values.second as bool;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Text(
              path.toLongString(inverted: invert, hideStandard: hideStandard),
              overflow: TextOverflow.visible,
            ),
          ),
        );
      },
    );
  }
}

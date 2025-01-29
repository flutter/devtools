// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../../shared/memory/retaining_path.dart';
import '../../../../../../shared/primitives/utils.dart';
import '../../../../../../shared/ui/common_widgets.dart';
import '../../controller/class_data.dart';

class RetainingPathView extends StatelessWidget {
  const RetainingPathView({
    super.key,
    required this.data,
    required this.controller,
  });

  final PathData data;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: densePadding),
          _PathControlPane(controller: controller, data: data),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: densePadding,
                left: densePadding,
              ),
              child: _PathView(path: data.path, controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathControlPane extends StatelessWidget {
  const _PathControlPane({required this.controller, required this.data});

  final PathData data;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    final titleText =
        'Retaining path for ${data.classData.className.className}';
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
          dataProvider: () => data.path.toLongString(delimiter: '\n'),
          // We do not give success message because it pops up directly on
          // top of the path widget, that makes the widget unavailable
          // while message is here.
          successMessage: null,
          gaScreen: gac.memory,
          gaItem: gac.MemoryEvents.diffPathCopy.name,
        ),
        const SizedBox(width: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.hideStandard,
          builder:
              (_, hideStandard, _) => DevToolsFilterButton(
                onPressed: () {
                  ga.select(
                    gac.memory,
                    '${gac.MemoryEvents.diffPathFilter.name}-$hideStandard',
                  );
                  controller.hideStandard.value =
                      !controller.hideStandard.value;
                },
                isFilterActive: hideStandard,
                message: 'Hide standard libraries',
              ),
        ),
        const SizedBox(width: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.invert,
          builder:
              (_, invert, _) => DevToolsToggleButton(
                onPressed: () {
                  ga.select(
                    gac.memory,
                    '${gac.MemoryEvents.diffPathInvert.name}-$invert',
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
      listenables: [controller.hideStandard, controller.invert],
      builder: (_, values, _) {
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

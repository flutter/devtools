// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/config_specific/launch_url/launch_url.dart';
import '../../../../shared/primitives/simple_items.dart';
import '../../shared/widgets/shared_memory_widgets.dart';
import 'controller/diff_pane_controller.dart';
import 'controller/item_controller.dart';
import 'widgets/snapshot_control_pane.dart';
import 'widgets/snapshot_list.dart';
import 'widgets/snapshot_view.dart';

class DiffPane extends StatelessWidget {
  const DiffPane({Key? key, required this.diffController}) : super(key: key);

  final DiffPaneController diffController;

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.1, 0.9],
      minSizes: const [80, 80],
      children: [
        OutlineDecoration.onlyRight(
          child: SnapshotList(controller: diffController),
        ),
        OutlineDecoration.onlyLeft(
          child: _SnapshotItemContent(
            controller: diffController,
          ),
        ),
      ],
    );
  }
}

class _SnapshotItemContent extends StatelessWidget {
  const _SnapshotItemContent({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  static const _documentationTopic = gac.MemoryEvent.diffHelp;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SnapshotItem>(
      valueListenable: controller.derived.selectedItem,
      builder: (_, item, __) {
        if (item is SnapshotDocItem) {
          return Padding(
            padding: const EdgeInsets.all(defaultSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      SizedBox(
                        height: 450,
                        child: Markdown(
                          data: _snapshotDocumentation,
                          onTapLink: (text, url, title) =>
                              unawaited(launchUrl(url!)),
                        ),
                      ),
                      const ClassTypeLegend(),
                    ],
                  ),
                ),
                MoreInfoLink(
                  url: DocLinks.diff.value,
                  gaScreenName: gac.memory,
                  gaSelectedItemDescription:
                      gac.topicDocumentationLink(_documentationTopic),
                ),
              ],
            ),
          );
        }

        return SnapshotInstanceItemPane(controller: controller);
      },
    );
  }
}

@visibleForTesting
class SnapshotInstanceItemPane extends StatelessWidget {
  const SnapshotInstanceItemPane({super.key, required this.controller});

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlineDecoration.onlyBottom(
          child: Padding(
            padding: const EdgeInsets.all(denseSpacing),
            child: SnapshotControlPane(controller: controller),
          ),
        ),
        Expanded(
          child: SnapshotView(
            controller: controller,
          ),
        ),
      ],
    );
  }
}

/// `\v` adds vertical space
const _snapshotDocumentation = '''
Find unexpected memory usage by comparing two heap snapshots:

\v

1. Understand [Dart memory concepts](https://docs.flutter.dev/development/tools/devtools/memory#basic-memory-concepts).

\v

2. Take a **heap snapshot** to view current memory allocation:

    a. In the Snapshots panel, click the ● button

    b. If you want to refine results, use the **Filter** button

    c. Select a class from the snapshot table to view its retaining paths

    d. View the path detail by selecting from the **Shortest Retaining Paths…** table

\v

3. Check the **diff** between snapshots to detect allocation issues:

    a. Take a **snapshot**

    b. Execute the feature in your application

    c. Take a second snapshot. If you are experiencing DevTools crashes due to size of snapshots,
       switch to the [desktop version](https://github.com/flutter/devtools/blob/master/BETA_TESTING.md).

    d. While viewing the second snapshot, click **Diff with:** and select the first snapshot from the drop-down menu;
    the results area will display the diff

    e. Use the **Filter** button to refine the diff results, if needed

    f. Select a class from the diff to view its retaining paths, and see which objects hold the references to those instances
''';

// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/simple_items.dart';
import '../../../../shared/utils.dart';
import '../../shared/widgets/shared_memory_widgets.dart';
import 'controller/diff_pane_controller.dart';
import 'controller/snapshot_item.dart';
import 'widgets/snapshot_control_pane.dart';
import 'widgets/snapshot_list.dart';
import 'widgets/snapshot_view.dart';

class DiffPane extends StatelessWidget {
  const DiffPane({super.key, required this.diffController});

  final DiffPaneController diffController;

  @override
  Widget build(BuildContext context) {
    return SplitPane(
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
  const _SnapshotItemContent({required this.controller});

  final DiffPaneController controller;

  static const _documentationTopic = gac.MemoryEvent.diffHelp;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SnapshotItem>(
      valueListenable: controller.derived.selectedItem,
      builder: (_, item, __) {
        if (item is SnapshotDocItem) {
          return Padding(
            padding: const EdgeInsets.all(denseSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Markdown(
                          data: _snapshotDocumentation(
                            preferences.darkModeTheme.value,
                          ),
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).regularTextStyle,
                          ),
                          onTapLink: (text, url, title) =>
                              unawaited(launchUrlWithErrorHandling(url!)),
                        ),
                      ),
                      const SizedBox(width: densePadding),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                              top: defaultSpacing,
                              right: denseSpacing,
                            ),
                            child: ClassTypeLegend(),
                          ),
                          MoreInfoLink(
                            url: DocLinks.diff.value,
                            gaScreenName: gac.memory,
                            gaSelectedItemDescription:
                                gac.topicDocumentationLink(_documentationTopic),
                          ),
                        ],
                      ),
                    ],
                  ),
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

String _snapshotDocumentation(bool isDark) {
  final filePostfix = isDark ? 'dark' : 'light';

  // TODO(polina-c): remove after fixing https://github.com/flutter/flutter/issues/149866
  const isWebProd = kIsWeb && !kDebugMode;
  const imagePath = isWebProd ? 'assets/' : '';
  final uploadImageUrl = '${imagePath}assets/img/doc/upload_$filePostfix.png';

  // `\v` adds vertical space
  return '''
Find unexpected memory usage by comparing two heap snapshots:

\v

1. Understand [Dart memory concepts](https://docs.flutter.dev/development/tools/devtools/memory#basic-memory-concepts).

\v

2. Use one of the following ways to get a **heap snapshot**:

    a. To take snapshot of the connected application click the ● button

    b. To import a snapshot exported from DevTools or taken with
    [auto-snapshotting](https://github.com/dart-lang/leak_tracker/blob/main/doc/USAGE.md) or
    [writeHeapSnapshotToFile](https://api.flutter.dev/flutter/dart-developer/NativeRuntime/writeHeapSnapshotToFile.html)
    click the ![import]($uploadImageUrl) button

\v

3. Review the snapshot:

    b. If you want to refine results, use the **Filter** button

    c. Select a class from the snapshot table to view its retaining paths

    d. View the path detail by selecting from the **Shortest Retaining Paths…** table

\v

4. Check the **diff** between snapshots to detect allocation issues:

    a. Get **snapshots** before and after a feature execution.
       If you are experiencing DevTools crashes due to size of snapshots,
       switch to the [desktop version](https://github.com/flutter/devtools/blob/master/BETA_TESTING.md).

    b. While viewing the second snapshot, click **Diff with:** and select the first snapshot from the drop-down menu;
    the results area will display the diff

    c. Use the **Filter** button to refine the diff results, if needed

    d. Select a class from the diff to view its retaining paths, and see which objects hold the references to those instances
''';
}

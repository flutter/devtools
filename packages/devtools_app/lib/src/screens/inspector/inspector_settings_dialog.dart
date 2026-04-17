// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/globals.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/editable_list.dart';

class FlutterInspectorSettingsDialog extends StatefulWidget {
  const FlutterInspectorSettingsDialog({super.key});

  @override
  State<FlutterInspectorSettingsDialog> createState() =>
      _FlutterInspectorSettingsDialogState();
}

class _FlutterInspectorSettingsDialogState
    extends State<FlutterInspectorSettingsDialog>
    with AutoDisposeMixin {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const dialogHeight = 500.0;

    return DevToolsDialog(
      title: const DialogTitleText('Flutter Inspector Settings'),
      content: SizedBox(
        width: defaultDialogWidth,
        height: dialogHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...dialogSubHeader(theme, 'General'),
            CheckboxSetting(
              notifier:
                  preferences.inspector.hoverEvalModeEnabled
                      as ValueNotifier<bool?>,
              title: 'Enable hover inspection',
              description:
                  'Hovering over any widget displays its properties and values.',
              gaItem: gac.inspectorHoverEvalMode,
            ),
            const SizedBox(height: largeSpacing),
            CheckboxSetting(
              notifier:
                  preferences.inspector.autoRefreshEnabled
                      as ValueNotifier<bool?>,
              title: 'Enable widget tree auto-refreshing',
              description:
                  'The widget tree will automatically refresh after a hot-reload or navigation event.',
              gaItem: gac.inspectorAutoRefreshEnabled,
            ),
            const SizedBox(height: largeSpacing),
            ...dialogSubHeader(theme, 'Package Directories'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Widgets in these directories will show up in your summary tree.',
                    style: theme.subtleTextStyle,
                  ),
                ),
                MoreInfoLink(
                  url: DocLinks.inspectorPackageDirectories.value,
                  gaScreenName: gac.inspector,
                  gaSelectedItemDescription:
                      gac.InspectorDocs.packageDirectoriesDocs.name,
                ),
              ],
            ),
            Text(
              '(e.g. /absolute/path/to/myPackage/)',
              style: theme.subtleTextStyle,
            ),
            const SizedBox(height: denseSpacing),
            const Expanded(child: PubRootDirectorySection()),
          ],
        ),
      ),
      actions: const [DialogCloseButton()],
    );
  }
}

class PubRootDirectorySection extends StatelessWidget {
  const PubRootDirectorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IsolateRef?>(
      valueListenable:
          serviceConnection.serviceManager.isolateManager.mainIsolate,
      builder: (_, _, _) {
        return SizedBox(
          height: 200.0,
          child: EditableList(
            gaScreen: gac.inspector,
            gaRefreshSelection: gac.refreshPubRoots,
            entries: preferences.inspector.pubRootDirectories,
            textFieldLabel: 'Enter a new package directory',
            isRefreshing: preferences.inspector.isRefreshingPubRootDirectories,
            onEntryAdded: (p0) => unawaited(
              preferences.inspector.addPubRootDirectories([
                p0,
              ], shouldCache: true),
            ),
            onEntryRemoved: (p0) =>
                unawaited(preferences.inspector.removePubRootDirectories([p0])),
            onRefreshTriggered: () =>
                unawaited(preferences.inspector.loadPubRootDirectories()),
          ),
        );
      },
    );
  }
}

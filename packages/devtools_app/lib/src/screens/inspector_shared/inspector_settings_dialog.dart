// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/globals.dart';
import '../../shared/preferences/preferences.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/editable_list.dart';

class FlutterInspectorSettingsDialog extends StatelessWidget {
  const FlutterInspectorSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogHeight = scaleByFontFactor(500.0);

    return ValueListenableBuilder(
      valueListenable: preferences.inspector.inspectorV2Enabled,
      builder: (context, inspectorV2Enabled, _) {
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
                if (inspectorV2Enabled) ...[
                  CheckboxSetting(
                    notifier:
                        preferences.inspector.autoRefreshEnabled
                            as ValueNotifier<bool?>,
                    title: 'Enable auto-refreshing of the widget tree',
                    description:
                        'The widget tree will automatically be refreshed after a hot-reload.',
                    gaItem: gac.inspectorAutoRefreshEnabled,
                  ),
                ] else ...[
                  const InspectorDefaultDetailsViewOption(),
                ],
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
      },
    );
  }
}

class InspectorDefaultDetailsViewOption extends StatelessWidget {
  const InspectorDefaultDetailsViewOption({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: preferences.inspector.defaultDetailsView,
      builder: (context, selection, _) {
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select the default tab for the inspector.',
              style: theme.subtleTextStyle,
            ),
            const SizedBox(height: denseSpacing),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<InspectorDetailsViewType>(
                  value: InspectorDetailsViewType.layoutExplorer,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  groupValue: selection,
                  onChanged: _onChanged,
                ),
                Text(InspectorDetailsViewType.layoutExplorer.key),
                const SizedBox(width: denseSpacing),
                Radio<InspectorDetailsViewType>(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: InspectorDetailsViewType.widgetDetailsTree,
                  groupValue: selection,
                  onChanged: _onChanged,
                ),
                Text(InspectorDetailsViewType.widgetDetailsTree.key),
              ],
            ),
          ],
        );
      },
    );
  }

  void _onChanged(InspectorDetailsViewType? value) {
    if (value != null) {
      preferences.inspector.setDefaultInspectorDetailsView(value);
      final item =
          value.name == InspectorDetailsViewType.layoutExplorer.name
              ? gac.defaultDetailsViewToLayoutExplorer
              : gac.defaultDetailsViewToWidgetDetails;
      ga.select(gac.inspector, item);
    }
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
            onEntryAdded:
                (p0) => unawaited(
                  preferences.inspector.addPubRootDirectories([
                    p0,
                  ], shouldCache: true),
                ),
            onEntryRemoved:
                (p0) => unawaited(
                  preferences.inspector.removePubRootDirectories([p0]),
                ),
            onRefreshTriggered:
                () => unawaited(preferences.inspector.loadPubRootDirectories()),
          ),
        );
      },
    );
  }
}

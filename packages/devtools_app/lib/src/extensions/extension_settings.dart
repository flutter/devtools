// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/globals.dart';

/// A [ScaffoldAction] that, when clicked, will open a dialog menu for
/// managing DevTools extension states.
class ExtensionSettingsAction extends ScaffoldAction {
  ExtensionSettingsAction({super.key, Color? color})
      : super(
          icon: Icons.extension_outlined,
          tooltip: 'DevTools Extensions',
          color: color,
          onPressed: (context) {
            unawaited(
              showDialog(
                context: context,
                builder: (context) => const ExtensionSettingsDialog(),
              ),
            );
          },
        );
}

class ExtensionSettingsDialog extends StatelessWidget {
  const ExtensionSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableExtensions = extensionService.availableExtensions.value;
    // This dialog needs a fixed height because it contains a scrollable list.
    final dialogHeight =
        anyTestMode ? scaleByFontFactor(1000.0) : scaleByFontFactor(300.0);
    return DevToolsDialog(
      title: const DialogTitleText('DevTools Extensions'),
      content: SizedBox(
        width: defaultDialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            const Text(
              'Extensions are provided by the pub packages used in your '
              'application. When activated, the tools provided by these '
              'extensions will be available in a separate DevTools tab.',
            ),
            const SizedBox(height: defaultSpacing),
            CheckboxSetting(
              notifier:
                  preferences.devToolsExtensions.showOnlyEnabledExtensions,
              title: 'Only show screens for enabled extensions',
              tooltip:
                  'Only show top-level DevTools tabs for extensions that are '
                  'enabled\n(i.e. do not show tabs for extensions that have no '
                  'preference set).',
            ),
            const PaddedDivider(),
            Expanded(
              child: availableExtensions.isEmpty
                  ? Center(
                      child: Text(
                        'No extensions available.',
                        style: theme.subtleTextStyle,
                      ),
                    )
                  : _ExtensionsList(extensions: availableExtensions),
            ),
          ],
        ),
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}

class _ExtensionsList extends StatefulWidget {
  const _ExtensionsList({required this.extensions});

  final List<DevToolsExtensionConfig> extensions;

  @override
  State<_ExtensionsList> createState() => __ExtensionsListState();
}

class __ExtensionsListState extends State<_ExtensionsList> {
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: scrollController,
        itemCount: widget.extensions.length,
        itemBuilder: (context, index) => ExtensionSetting(
          extension: widget.extensions[index],
        ),
      ),
    );
  }
}

@visibleForTesting
class ExtensionSetting extends StatelessWidget {
  const ExtensionSetting({super.key, required this.extension});

  final DevToolsExtensionConfig extension;

  @override
  Widget build(BuildContext context) {
    final buttonStates = [
      (
        title: 'Enabled',
        isSelected: (ExtensionEnabledState state) =>
            state == ExtensionEnabledState.enabled,
        onPressed: () {
          ga.select(
            gac.DevToolsExtensionEvents.extensionSettingsId.name,
            gac.DevToolsExtensionEvents.extensionEnableManual(extension),
          );
          unawaited(
            extensionService.setExtensionEnabledState(
              extension,
              enable: true,
            ),
          );
        },
      ),
      (
        title: 'Disabled',
        isSelected: (ExtensionEnabledState state) =>
            state == ExtensionEnabledState.disabled,
        onPressed: () {
          ga.select(
            gac.DevToolsExtensionEvents.extensionSettingsId.name,
            gac.DevToolsExtensionEvents.extensionDisableManual(extension),
          );
          unawaited(
            extensionService.setExtensionEnabledState(
              extension,
              enable: false,
            ),
          );
        },
      ),
    ];
    final theme = Theme.of(context);
    final extensionName = extension.name.toLowerCase();
    return ValueListenableBuilder(
      valueListenable: extensionService.enabledStateListenable(extensionName),
      builder: (context, enabledState, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: denseSpacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'package:$extensionName',
                overflow: TextOverflow.ellipsis,
                style: theme.fixedFontStyle,
              ),
              DevToolsToggleButtonGroup(
                fillColor: theme.colorScheme.primary,
                selectedColor: theme.colorScheme.onPrimary,
                onPressed: (index) => buttonStates[index].onPressed(),
                selectedStates: [
                  for (final state in buttonStates)
                    state.isSelected(enabledState),
                ],
                children: [
                  for (final state in buttonStates)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: densePadding,
                        horizontal: denseSpacing,
                      ),
                      child: Text(state.title),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

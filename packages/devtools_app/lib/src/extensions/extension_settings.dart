// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/framework/routing.dart';
import '../shared/globals.dart';
import '../shared/ui/common_widgets.dart';
import 'extension_screen.dart';

/// A [ScaffoldAction] that, when clicked, will open a dialog menu for
/// managing DevTools extension states.
class ExtensionSettingsAction extends ScaffoldAction {
  ExtensionSettingsAction({super.key, super.color})
    : super(
        iconAsset: 'icons/app_bar/devtools_extensions.png',
        tooltip: 'DevTools Extensions',
        onPressed: (context) {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => ExtensionSettingsDialog(
                extensions: extensionService
                    .currentExtensions
                    .value
                    .availableExtensions,
              ),
            ),
          );
        },
      );
}

@visibleForTesting
class ExtensionSettingsDialog extends StatelessWidget {
  const ExtensionSettingsDialog({required this.extensions, super.key});

  final List<DevToolsExtensionConfig> extensions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // This dialog needs a fixed height because it contains a scrollable list.
    final dialogHeight = anyTestMode ? 1000.0 : 300.0;
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
              child: extensions.isEmpty
                  ? Center(
                      child: Text(
                        'No extensions available.',
                        style: theme.subtleTextStyle,
                      ),
                    )
                  : _ExtensionsList(extensions: extensions),
            ),
          ],
        ),
      ),
      actions: const [DialogCloseButton()],
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
        itemBuilder: (context, index) =>
            ExtensionSetting(extension: widget.extensions[index]),
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
            extensionService.setExtensionEnabledState(extension, enable: true),
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
            extensionService.setExtensionEnabledState(extension, enable: false),
          );
          final router = DevToolsRouterDelegate.of(context);
          if (router.currentConfiguration?.page == extension.screenId) {
            router.navigateHome(clearScreenParam: true);
          }
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

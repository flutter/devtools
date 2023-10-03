// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../app.dart';
import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/globals.dart';

class EmbeddedExtensionHeader extends StatelessWidget {
  const EmbeddedExtensionHeader({
    super.key,
    required this.extension,
    required this.onForceReload,
  });

  final DevToolsExtensionConfig extension;

  final VoidCallback onForceReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extensionName = extension.displayName;
    return Row(
      children: [
        RichText(
          text: TextSpan(
            text: 'package:$extensionName extension',
            style: theme.regularTextStyle.copyWith(fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: ' (v${extension.version})',
                style: theme.subtleTextStyle,
              ),
            ],
          ),
        ),
        const Spacer(),
        RichText(
          text: LinkTextSpan(
            link: Link(
              display: 'Report an issue',
              url: extension.issueTrackerLink,
              gaScreenName: gac.DevToolsExtensionEvents.extensionScreenId.name,
              gaSelectedItemDescription:
                  gac.DevToolsExtensionEvents.extensionFeedback(extensionName),
            ),
            context: context,
          ),
        ),
        const SizedBox(width: denseSpacing),
        ValueListenableBuilder<ExtensionEnabledState>(
          valueListenable:
              extensionService.enabledStateListenable(extension.displayName),
          builder: (context, activationState, _) {
            if (activationState == ExtensionEnabledState.enabled) {
              return ContextMenuButton(
                iconSize: defaultIconSize,
                buttonWidth: buttonMinWidth,
                menuChildren: <Widget>[
                  PointerInterceptor(
                    child: MenuItemButton(
                      onPressed: () {
                        // Do not send analytics here because the user must
                        // confirm that they want to disable the extension from
                        // the [DisableExtensionDialog]. Analytics will be sent
                        // there if they confirm that they'd like to disable the
                        // extension.
                        unawaited(
                          showDialog(
                            context: context,
                            builder: (_) =>
                                DisableExtensionDialog(extension: extension),
                          ),
                        );
                      },
                      child: const MaterialIconLabel(
                        label: 'Disable extension',
                        iconData: Icons.extension_off_outlined,
                      ),
                    ),
                  ),
                  PointerInterceptor(
                    child: MenuItemButton(
                      onPressed: () {
                        ga.select(
                          gac.DevToolsExtensionEvents.extensionScreenId.name,
                          gac.DevToolsExtensionEvents.extensionForceReload(
                            extension.displayName,
                          ),
                        );
                        onForceReload();
                      },
                      child: const MaterialIconLabel(
                        label: 'Force reload extension',
                        iconData: Icons.refresh,
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

@visibleForTesting
class DisableExtensionDialog extends StatelessWidget {
  const DisableExtensionDialog({super.key, required this.extension});

  final DevToolsExtensionConfig extension;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: const DialogTitleText('Disable extension?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: 'Are you sure you want to disable the ',
              style: theme.regularTextStyle,
              children: [
                TextSpan(
                  text: extension.displayName,
                  style: theme.fixedFontStyle,
                ),
                const TextSpan(text: ' extension?'),
              ],
            ),
          ),
          const SizedBox(height: denseSpacing),
          RichText(
            text: TextSpan(
              text: 'You can always re-enable this extension later from the ',
              style: theme.regularTextStyle,
              children: [
                TextSpan(
                  text: 'DevTools Extensions ',
                  style: theme.boldTextStyle,
                ),
                WidgetSpan(
                  child: Icon(
                    Icons.extension_rounded,
                    size: defaultIconSize,
                  ),
                ),
                const TextSpan(text: ' menu.'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        DialogTextButton(
          onPressed: () {
            ga.select(
              gac.DevToolsExtensionEvents.extensionScreenId.name,
              gac.DevToolsExtensionEvents.extensionDisableManual(
                extension.displayName,
              ),
            );
            unawaited(
              extensionService.setExtensionEnabledState(
                extension,
                enable: false,
              ),
            );
            Navigator.of(context).pop(dialogDefaultContext);
            DevToolsApp.of(context)
                .navigateHome(clearScreenParam: true);
          },
          child: const Text('YES, DISABLE'),
        ),
        const DialogCancelButton(),
      ],
    );
  }
}

class EnableExtensionPrompt extends StatelessWidget {
  const EnableExtensionPrompt({
    super.key,
    required this.extension,
  });

  final DevToolsExtensionConfig extension;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extensionName = extension.displayName;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: 'The ',
              style: theme.regularTextStyle,
              children: [
                TextSpan(
                  text: extension.name,
                  style: theme.fixedFontStyle,
                ),
                const TextSpan(
                  text: ' extension has not been enabled. Do you want to enable'
                      ' this extension?\nYou can always change this setting '
                      'later from the DevTools Extensions ',
                ),
                WidgetSpan(
                  child: Icon(
                    Icons.extension_outlined,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const TextSpan(
                  text: ' menu. ',
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GaDevToolsButton(
                label: 'Enable',
                gaScreen: gac.DevToolsExtensionEvents.extensionScreenId.name,
                gaSelection: gac.DevToolsExtensionEvents.extensionEnablePrompt(
                  extensionName,
                ),
                elevated: true,
                onPressed: () {
                  unawaited(
                    extensionService.setExtensionEnabledState(
                      extension,
                      enable: true,
                    ),
                  );
                },
              ),
              const SizedBox(width: defaultSpacing),
              GaDevToolsButton(
                label: 'No, hide this screen',
                gaScreen: gac.DevToolsExtensionEvents.extensionScreenId.name,
                gaSelection: gac.DevToolsExtensionEvents.extensionDisablePrompt(
                  extensionName,
                ),
                onPressed: () {
                  unawaited(
                    extensionService.setExtensionEnabledState(
                      extension,
                      enable: false,
                    ),
                  );
                  DevToolsApp.of(context)
                      .navigateHome(clearScreenParam: true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

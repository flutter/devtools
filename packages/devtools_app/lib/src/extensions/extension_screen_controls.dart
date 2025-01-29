// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/framework/routing.dart';
import '../shared/globals.dart';
import '../shared/ui/common_widgets.dart';

class EmbeddedExtensionHeader extends StatelessWidget {
  const EmbeddedExtensionHeader({
    super.key,
    required this.ext,
    required this.onForceReload,
  });

  final DevToolsExtensionConfig ext;

  final VoidCallback onForceReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extensionName = ext.displayName;
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: borderPadding),
            child: RichText(
              text: TextSpan(
                text: 'package:$extensionName extension',
                style: theme.regularTextStyle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: ' (v${ext.version})',
                    style: theme.subtleTextStyle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: denseSpacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: GaLinkTextSpan(
                  link: GaLink(
                    display: 'Report an issue',
                    url: ext.issueTrackerLink,
                    gaScreenName:
                        gac.DevToolsExtensionEvents.extensionScreenId.name,
                    gaSelectedItemDescription: gac
                        .DevToolsExtensionEvents.extensionFeedback(ext),
                  ),
                  context: context,
                ),
              ),
              const SizedBox(width: denseSpacing),
              _ExtensionContextMenuButton(
                ext: ext,
                onForceReload: onForceReload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtensionContextMenuButton extends StatelessWidget {
  const _ExtensionContextMenuButton({
    required this.ext,
    required this.onForceReload,
  });

  final DevToolsExtensionConfig ext;

  final VoidCallback onForceReload;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ExtensionEnabledState>(
      valueListenable: extensionService.enabledStateListenable(ext.displayName),
      builder: (context, activationState, _) {
        if (activationState != ExtensionEnabledState.enabled) {
          return const SizedBox.shrink();
        }
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
                      builder: (_) => DisableExtensionDialog(ext: ext),
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
                    gac.DevToolsExtensionEvents.extensionForceReload(ext),
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
      },
    );
  }
}

@visibleForTesting
class DisableExtensionDialog extends StatelessWidget {
  const DisableExtensionDialog({super.key, required this.ext});

  final DevToolsExtensionConfig ext;

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
                TextSpan(text: ext.displayName, style: theme.fixedFontStyle),
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
                  child: Icon(Icons.extension_rounded, size: defaultIconSize),
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
              gac.DevToolsExtensionEvents.extensionDisableManual(ext),
            );
            unawaited(
              extensionService.setExtensionEnabledState(ext, enable: false),
            );
            Navigator.of(context).pop(dialogDefaultContext);
            DevToolsRouterDelegate.of(
              context,
            ).navigateHome(clearScreenParam: true);
          },
          child: const Text('YES, DISABLE'),
        ),
        const DialogCancelButton(),
      ],
    );
  }
}

class EnableExtensionPrompt extends StatelessWidget {
  const EnableExtensionPrompt({super.key, required this.ext});

  final DevToolsExtensionConfig ext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                TextSpan(text: ext.name, style: theme.fixedFontStyle),
                const TextSpan(
                  text:
                      ' extension has not been enabled. Do you want to enable'
                      ' this extension?\nYou can always change this setting '
                      'later from the DevTools Extensions ',
                ),
                WidgetSpan(
                  child: Icon(
                    Icons.extension_outlined,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const TextSpan(text: ' menu. '),
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
                  ext,
                ),
                elevated: true,
                onPressed: () {
                  unawaited(
                    extensionService.setExtensionEnabledState(
                      ext,
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
                  ext,
                ),
                onPressed: () {
                  unawaited(
                    extensionService.setExtensionEnabledState(
                      ext,
                      enable: false,
                    ),
                  );
                  DevToolsRouterDelegate.of(
                    context,
                  ).navigateHome(clearScreenParam: true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

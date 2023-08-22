// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import '../shared/routing.dart';

class EmbeddedExtensionHeader extends StatelessWidget {
  const EmbeddedExtensionHeader({super.key, required this.extension});

  final DevToolsExtensionConfig extension;

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
              gaScreenName: gac.extensionScreenId,
              gaSelectedItemDescription: gac.extensionFeedback(extensionName),
            ),
            context: context,
          ),
        ),
        ValueListenableBuilder<ExtensionEnabledState>(
          valueListenable:
              extensionService.enabledStateListenable(extension.displayName),
          builder: (context, activationState, _) {
            if (activationState == ExtensionEnabledState.enabled) {
              return Padding(
                padding: const EdgeInsets.only(left: denseSpacing),
                child: DisableExtensionButton(extension: extension),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(width: defaultSpacing),
      ],
    );
  }
}

@visibleForTesting
class DisableExtensionButton extends StatelessWidget {
  const DisableExtensionButton({super.key, required this.extension});

  final DevToolsExtensionConfig extension;

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton.iconOnly(
      icon: Icons.extension_off_outlined,
      tooltip: 'Disable extension',
      gaScreen: gac.extensionScreenId,
      gaSelection: gac.extensionDisable(extension.displayName),
      onPressed: () => unawaited(
        showDialog(
          context: context,
          builder: (_) => DisableExtensionDialog(extension: extension),
        ),
      ),
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
            unawaited(
              extensionService.setExtensionEnabledState(
                extension,
                enable: false,
              ),
            );
            Navigator.of(context).pop(dialogDefaultContext);
            DevToolsRouterDelegate.of(context)
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
                      ' this extension?',
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
                gaScreen: gac.extensionScreenId,
                gaSelection: gac.extensionEnable(extensionName),
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
                gaScreen: gac.extensionScreenId,
                gaSelection: gac.extensionDisable(extensionName),
                onPressed: () {
                  unawaited(
                    extensionService.setExtensionEnabledState(
                      extension,
                      enable: false,
                    ),
                  );
                  DevToolsRouterDelegate.of(context)
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

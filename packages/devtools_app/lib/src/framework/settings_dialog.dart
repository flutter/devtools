// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/analytics/analytics_controller.dart';
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/config_specific/copy_to_clipboard/copy_to_clipboard.dart';
import '../shared/feature_flags.dart';
import '../shared/globals.dart';
import '../shared/log_storage.dart';
import '../shared/server/server.dart';

class OpenSettingsAction extends ScaffoldAction {
  OpenSettingsAction({super.key, super.color})
      : super(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onPressed: (context) {
            unawaited(
              showDialog(
                context: context,
                builder: (context) => const SettingsDialog(),
              ),
            );
          },
        );
}

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analyticsController = Provider.of<AnalyticsController>(context);
    return DevToolsDialog(
      title: const DialogTitleText('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isEmbedded())
            Flexible(
              child: CheckboxSetting(
                title: 'Use a dark theme',
                notifier: preferences.darkModeEnabled,
                onChanged: preferences.toggleDarkModeTheme,
                gaScreen: gac.settingsDialog,
                gaItem: gac.darkTheme,
              ),
            ),
          if (isExternalBuild && isDevToolsServerAvailable)
            Flexible(
              child: CheckboxSetting(
                title: 'Enable analytics',
                notifier: analyticsController.analyticsEnabled,
                onChanged: (enable) => unawaited(
                  analyticsController.toggleAnalyticsEnabled(enable),
                ),
                gaScreen: gac.settingsDialog,
                gaItem: gac.analytics,
              ),
            ),
          Flexible(
            child: CheckboxSetting(
              title: 'Enable VM developer mode',
              notifier: preferences.vmDeveloperModeEnabled,
              onChanged: preferences.toggleVmDeveloperMode,
              gaScreen: gac.settingsDialog,
              gaItem: gac.vmDeveloperMode,
            ),
          ),
          if (FeatureFlags.wasmOptInSetting) ...[
            const SizedBox(height: largeSpacing),
            ...dialogSubHeader(theme, 'Experimental features'),
            Flexible(
              child: CheckboxSetting(
                title: 'Enable WebAssembly',
                description:
                    'This will trigger a reload of the page to load DevTools '
                    'compiled with WebAssembly. This may yield better '
                    'performance.',
                notifier: preferences.wasmEnabled,
                onChanged: preferences.toggleWasmEnabled,
                gaScreen: gac.settingsDialog,
                gaItem: gac.wasm,
              ),
            ),
            // TODO(https://github.com/flutter/devtools/issues/7860): Clean-up
            // after Inspector V2 has been released.
            if (FeatureFlags.inspectorV2)
              Flexible(
                child: CheckboxSetting(
                  notifier: preferences.inspector.inspectorV2Enabled
                      as ValueNotifier<bool?>,
                  title: 'Enable the new Inspector',
                  description: 'Try out the redesigned Flutter Inspector.',
                  gaItem: gac.inspectorV2Enabled,
                ),
              ),
          ],
          const SizedBox(height: largeSpacing),
          ...dialogSubHeader(theme, 'Troubleshooting'),
          const _VerboseLoggingSetting(),
        ],
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}

class _VerboseLoggingSetting extends StatelessWidget {
  const _VerboseLoggingSetting();

  static const _minScreenWidthForTextBeforeScaling = 500.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Flexible(
              child: CheckboxSetting(
                title: 'Enable verbose logging',
                notifier: preferences.verboseLoggingEnabled,
                onChanged: (enable) => preferences.toggleVerboseLogging(enable),
                gaScreen: gac.settingsDialog,
                gaItem: gac.verboseLogging,
              ),
            ),
            const SizedBox(width: defaultSpacing),
            GaDevToolsButton(
              label: 'Copy logs',
              icon: Icons.copy_outlined,
              gaScreen: gac.settingsDialog,
              gaSelection: gac.copyLogs,
              minScreenWidthForTextBeforeScaling:
                  _minScreenWidthForTextBeforeScaling,
              onPressed: () async => await copyToClipboard(
                LogStorage.root.toString(),
                successMessage: 'Successfully copied logs',
              ),
            ),
            const SizedBox(width: denseSpacing),
            ClearButton(
              label: 'Clear logs',
              gaScreen: gac.settingsDialog,
              gaSelection: gac.clearLogs,
              minScreenWidthForTextBeforeScaling:
                  _minScreenWidthForTextBeforeScaling,
              onPressed: LogStorage.root.clear,
            ),
          ],
        ),
        const SizedBox(height: denseSpacing),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning),
            SizedBox(width: defaultSpacing),
            Flexible(
              child: Text(
                'Logs may contain sensitive information.\n'
                'Always check their contents before sharing.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

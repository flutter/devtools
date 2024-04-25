// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../../extensions/extension_screen.dart';
import '../../extensions/extension_service.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/screen.dart';
import '../api/vs_code_api.dart';

/// A widget that displays DevTools options, including buttons to open static
/// screens, and a list of static DevTools extensions available for the IDE
/// workspace.
class DevToolsSidebarOptions extends StatelessWidget {
  const DevToolsSidebarOptions({
    required this.api,
    required this.hasDebugSessions,
    super.key,
  });

  final VsCodeApi api;
  final bool hasDebugSessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DevTools',
          style: theme.textTheme.titleMedium,
        ),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final screen
                in ScreenMetaData.values.where(_shouldIncludeScreen))
              _createDevToolsScreenRow(
                label: screen.title ?? screen.id,
                icon: screen.icon!,
                screenId: screen.id,
                api: api,
                theme: theme,
              ),
            if (api.capabilities.openDevToolsExternally)
              _createDevToolsScreenRow(
                label: 'Open in Browser',
                icon: Icons.open_in_browser,
                api: api,
                theme: theme,
                onPressed: () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.VsCodeFlutterSidebar.openDevToolsExternally.name,
                  );
                  unawaited(api.openDevToolsPage(null, forceExternal: true));
                },
              ),
          ],
        ),
        const PaddedDivider.thin(),
        _RuntimeToolInstructions(
          hasDebugSessions: hasDebugSessions,
          toolDescription: 'tools',
        ),
        const SizedBox(height: denseSpacing),
        _DevToolsExtensions(
          api: api,
          hasDebugSessions: hasDebugSessions,
        ),
      ],
    );
  }

  bool _shouldIncludeScreen(ScreenMetaData screen) {
    return switch (screen) {
      ScreenMetaData.home => false,
      ScreenMetaData.vmTools => false,
      // The performance and cpu profiler pages just show an option to load
      // offline data. Hide them as they aren't that useful without a running
      // app.
      ScreenMetaData.performance => false,
      ScreenMetaData.cpuProfiler => false,
      _ => !screen.requiresConnection,
    };
  }
}

class _DevToolsExtensions extends StatefulWidget {
  const _DevToolsExtensions({
    required this.api,
    required this.hasDebugSessions,
  });

  final VsCodeApi api;
  final bool hasDebugSessions;

  @override
  State<_DevToolsExtensions> createState() => _DevToolsExtensionsState();
}

class _DevToolsExtensionsState extends State<_DevToolsExtensions>
    with AutoDisposeMixin {
  ExtensionService? _extensionService;

  var extensions = <DevToolsExtensionConfig>[];

  @override
  void initState() {
    super.initState();
    _initExtensions();
  }

  void _initExtensions() {
    _extensionService = ExtensionService(ignoreServiceConnection: true);

    cancelListeners();
    extensions = _extensionService!.visibleExtensions.value;
    addAutoDisposeListener(_extensionService!.visibleExtensions, () {
      extensions = _extensionService!.visibleExtensions.value;
    });

    unawaited(_extensionService!.initialize());
  }

  @override
  void dispose() {
    _extensionService?.dispose();
    _extensionService = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (extensions.isEmpty) return const SizedBox();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DevTools Extensions',
          style: theme.textTheme.titleMedium,
        ),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final ext in extensions)
              _createDevToolsScreenRow(
                label: ext.name,
                icon: ext.icon,
                api: widget.api,
                theme: theme,
                onPressed: () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.VsCodeFlutterSidebar.openDevToolsScreen(
                      gac.DevToolsExtensionEvents.extensionScreenName(ext),
                    ),
                  );
                  unawaited(
                    widget.api.openDevToolsPage(null, page: ext.screenId),
                  );
                },
              ),
          ],
        ),
        const PaddedDivider.thin(),
        _RuntimeToolInstructions(
          hasDebugSessions: widget.hasDebugSessions,
          toolDescription: 'extensions',
        ),
      ],
    );
  }
}

TableRow _createDevToolsScreenRow({
  required String label,
  required IconData icon,
  required VsCodeApi api,
  required ThemeData theme,
  String? screenId,
  void Function()? onPressed,
}) {
  assert(
    screenId != null || onPressed != null,
    'screenId and onPressed cannot both be null',
  );
  final color = theme.colorScheme.secondary;
  return TableRow(
    children: [
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            shape: const ContinuousRectangleBorder(),
            textStyle: theme.regularTextStyle,
          ),
          icon: Icon(
            icon,
            size: actionsIconSize,
            color: color,
          ),
          label: Text(
            label,
            style: theme.regularTextStyle.copyWith(color: color),
          ),
          onPressed: onPressed ??
              () {
                ga.select(
                  gac.VsCodeFlutterSidebar.id,
                  gac.VsCodeFlutterSidebar.openDevToolsScreen(screenId!),
                );
                unawaited(api.openDevToolsPage(null, page: screenId));
              },
        ),
      ),
    ],
  );
}

class _RuntimeToolInstructions extends StatelessWidget {
  const _RuntimeToolInstructions({
    required this.hasDebugSessions,
    required this.toolDescription,
  });

  final bool hasDebugSessions;
  final String toolDescription;

  @override
  Widget build(BuildContext context) {
    final instruction = hasDebugSessions
        ? 'Open the tools menu for a debug session to access'
        : 'Begin a debug session to use';
    return Padding(
      padding: const EdgeInsets.only(left: borderPadding),
      child: Text(
        '$instruction $toolDescription that require a running application.',
      ),
    );
  }
}

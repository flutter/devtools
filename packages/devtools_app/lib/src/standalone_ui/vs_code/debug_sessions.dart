// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/constants.dart';
import '../../shared/feature_flags.dart';
import '../../shared/screen.dart';
import '../api/vs_code_api.dart';

class DebugSessions extends StatelessWidget {
  const DebugSessions({
    required this.api,
    required this.sessions,
    required this.deviceMap,
    super.key,
  });

  final VsCodeApi api;
  final List<VsCodeDebugSession> sessions;
  final Map<String, VsCodeDevice> deviceMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Debug Sessions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (sessions.isEmpty)
          const Text('Begin a debug session to use DevTools.')
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(),
            },
            defaultColumnWidth:
                FixedColumnWidth(actionsIconSize + denseSpacing),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final session in sessions)
                _debugSessionRow(session, context),
            ],
          ),
      ],
    );
  }

  TableRow _debugSessionRow(VsCodeDebugSession session, BuildContext context) {
    final mode = session.flutterMode;
    final isDebug = mode == 'debug';
    final isProfile = mode == 'profile';
    final isRelease = mode == 'release' || mode == 'jit_release';
    final isFlutter = session.debuggerType?.contains('Flutter') ?? false;
    final isWeb = deviceMap[session.flutterDeviceId]?.platformType == 'web';

    final label = session.flutterMode != null
        ? '${session.name} (${session.flutterMode})'
        : session.name;

    return TableRow(
      children: [
        Text(
          label,
          style: Theme.of(context).regularTextStyle,
        ),
        IconButton(
          onPressed: api.capabilities.hotReload && (isDebug || !isFlutter)
              ? () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.hotReload,
                  );
                  unawaited(api.hotReload(session.id));
                }
              : null,
          tooltip: 'Hot Reload',
          icon: Icon(hotReloadIcon, size: actionsIconSize),
        ),
        IconButton(
          onPressed: api.capabilities.hotRestart && (isDebug || !isFlutter)
              ? () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.hotRestart,
                  );
                  unawaited(api.hotRestart(session.id));
                }
              : null,
          tooltip: 'Hot Restart',
          icon: Icon(hotRestartIcon, size: actionsIconSize),
        ),
        if (api.capabilities.openDevToolsPage)
          _DevToolsMenu(
            api: api,
            session: session,
            isFlutter: isFlutter,
            isDebug: isDebug,
            isProfile: isProfile,
            isRelease: isRelease,
            isWeb: isWeb,
          ),
      ],
    );
  }
}

class _DevToolsMenu extends StatelessWidget {
  const _DevToolsMenu({
    required this.api,
    required this.session,
    required this.isFlutter,
    required this.isDebug,
    required this.isProfile,
    required this.isRelease,
    required this.isWeb,
  });

  final VsCodeApi api;
  final VsCodeDebugSession session;
  final bool isFlutter;
  final bool isDebug;
  final bool isProfile;
  final bool isRelease;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final normalDirection = Directionality.of(context);
    final reversedDirection = normalDirection == TextDirection.ltr
        ? TextDirection.rtl
        : TextDirection.ltr;

    Widget devToolsButton(ScreenMetaData screen) {
      final title = screen.title ?? screen.id;
      String? disabledReason;
      if (isRelease) {
        disabledReason = 'Not available in release mode';
      } else if (screen.requiresFlutter && !isFlutter) {
        disabledReason = 'Only available for Flutter applications';
      } else if (screen.requiresDebugBuild && !isDebug) {
        disabledReason = 'Only available in debug mode';
      } else if (screen.requiresDartVm && isWeb) {
        disabledReason = 'Not available when running on the web';
      }

      // Because we flipped the direction so the menu is aligned to the end, we
      // should revert the text direction back to normal for the label.
      Widget text = Directionality(
        textDirection: normalDirection,
        child: Text(title),
      );

      if (disabledReason != null) {
        text = Tooltip(
          preferBelow: false,
          message: disabledReason,
          child: text,
        );
      }

      return MenuItemButton(
        leadingIcon: Icon(screen.icon, size: actionsIconSize),
        onPressed: disabledReason != null
            ? null
            : () {
                ga.select(
                  gac.VsCodeFlutterSidebar.id,
                  gac.VsCodeFlutterSidebar.openDevToolsScreen(screen.id),
                );
                unawaited(api.openDevToolsPage(session.id, screen.id));
              },
        child: text,
      );
    }

    return Directionality(
      // Reverse the direction so the menu is anchored on the far side and
      // expands in the opposite direction with the icons on the right.
      textDirection: reversedDirection,
      child: MenuAnchor(
        style: const MenuStyle(
          alignment: AlignmentDirectional.bottomStart,
        ),
        menuChildren: ScreenMetaData.values
            .where(_shouldIncludeScreen)
            .map(devToolsButton)
            .toList(),
        builder: (context, controller, child) => IconButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          tooltip: 'DevTools',
          icon: Icon(
            Icons.construction,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }

  bool _shouldIncludeScreen(ScreenMetaData screen) {
    return switch (screen) {
      // Some screens shouldn't show up in the menu.
      ScreenMetaData.home => false,
      ScreenMetaData.debugger => false,
      ScreenMetaData.simple => false, // generic screen isn't a screen itself
      // TODO(dantup): Check preferences.vmDeveloperModeEnabled
      ScreenMetaData.vmTools => false,
      // DeepLink is currently behind a feature flag.
      ScreenMetaData.deepLinks => FeatureFlags.deepLinkValidation,
      // Anything else can be shown as long as it doesn't require a specific
      // library.
      _ => screen.requiresLibrary == null,
    };
  }
}

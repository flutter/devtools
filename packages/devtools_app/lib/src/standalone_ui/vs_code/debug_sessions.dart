// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../../extensions/extension_screen.dart';
import '../../extensions/extension_service.dart';
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

class _DevToolsMenu extends StatefulWidget {
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
  State<_DevToolsMenu> createState() => _DevToolsMenuState();
}

class _DevToolsMenuState extends State<_DevToolsMenu> {
  ExtensionService? _extensionServiceForSession;

  @override
  void initState() {
    super.initState();
    unawaited(_initExtensions());
  }

  Future<void> _initExtensions() async {
    final sessionRootPath = widget.session.projectRootPath;
    if (sessionRootPath != null) {
      setState(() {
        _extensionServiceForSession =
            ExtensionService(fixedAppRootPath: sessionRootPath);
        unawaited(_extensionServiceForSession!.initialize());
      });
    }
  }

  @override
  void didUpdateWidget(_DevToolsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _extensionServiceForSession?.dispose();
      unawaited(_initExtensions());
    }
  }

  @override
  void dispose() {
    _extensionServiceForSession?.dispose();
    _extensionServiceForSession = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalDirection = Directionality.of(context);
    final reversedDirection = normalDirection == TextDirection.ltr
        ? TextDirection.rtl
        : TextDirection.ltr;

    Widget devToolsButton(ScreenMetaData screen) {
      final title = screen.title ?? screen.id;
      String? disabledReason;
      if (widget.isRelease) {
        disabledReason = 'Not available in release mode';
      } else if (screen.requiresFlutter && !widget.isFlutter) {
        disabledReason = 'Only available for Flutter applications';
      } else if (screen.requiresDebugBuild && !widget.isDebug) {
        disabledReason = 'Only available in debug mode';
      } else if (screen.requiresDartVm && widget.isWeb) {
        disabledReason = 'Not available when running on the web';
      }

      return DevToolsScreenMenuItem(
        title: title,
        icon: screen.icon!,
        disabledReason: disabledReason,
        onPressed: () {
          ga.select(
            gac.VsCodeFlutterSidebar.id,
            gac.VsCodeFlutterSidebar.openDevToolsScreen(screen.id),
          );
          unawaited(widget.api.openDevToolsPage(widget.session.id, screen.id));
        },
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
        menuChildren: [
          ...ScreenMetaData.values
              .where(_shouldIncludeScreen)
              .map(devToolsButton)
              .toList(),
          if (_extensionServiceForSession != null)
            ValueListenableBuilder(
              valueListenable: _extensionServiceForSession!.visibleExtensions,
              builder: (context, extensions, _) {
                return extensions.isEmpty
                    ? const SizedBox.shrink()
                    : ExtensionScreenMenuItem(extensions: extensions);
              },
            ),
        ],
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

class DevToolsScreenMenuItem extends StatelessWidget {
  const DevToolsScreenMenuItem({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
    this.disabledReason,
  });

  final String title;
  final IconData icon;
  final VoidCallback onPressed;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    Widget text = Text(title);
    if (disabledReason != null) {
      text = Tooltip(
        preferBelow: false,
        message: disabledReason,
        child: text,
      );
    }

    return MenuItemButton(
      leadingIcon: Icon(icon, size: actionsIconSize),
      onPressed: disabledReason != null ? null : onPressed,
      child: text,
    );
  }
}

class ExtensionScreenMenuItem extends StatelessWidget {
  const ExtensionScreenMenuItem({super.key, required this.extensions});

  final List<DevToolsExtensionConfig> extensions;

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      menuStyle: const MenuStyle(
        alignment: Alignment.centerLeft,
      ),
      menuChildren: extensions
          .map(
            (e) => DevToolsScreenMenuItem(
              title: e.name,
              icon: e.icon,
              // TODO: this should open the extension screen in the browser,
              // or if possible, in an embedded iFrame in VS code.
              onPressed: () {},
            ),
          )
          .toList(),
      child: const Text('Extensions'),
    );
  }
}

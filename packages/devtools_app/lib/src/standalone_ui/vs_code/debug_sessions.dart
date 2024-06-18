// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../../extensions/extension_screen.dart';
import '../../extensions/extension_service.dart';
import '../../service/editor/api_classes.dart';
import '../../service/editor/editor_client.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/constants.dart';
import '../../shared/feature_flags.dart';
import '../../shared/screen.dart';

class DebugSessions extends StatelessWidget {
  const DebugSessions({
    required this.editor,
    required this.sessions,
    required this.devices,
    super.key,
  });

  final EditorClient editor;

  /// A map of debug session IDs to their debug sessions.
  final Map<String, EditorDebugSession> sessions;

  /// A map of device IDs to their devices.
  final Map<String, EditorDevice> devices;

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
          const Padding(
            padding: EdgeInsets.only(left: borderPadding),
            child: Text('No debug sessions'),
          )
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(),
            },
            defaultColumnWidth:
                FixedColumnWidth(actionsIconSize + denseSpacing),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final session in sessions.values)
                _debugSessionRow(session, context),
            ],
          ),
      ],
    );
  }

  TableRow _debugSessionRow(EditorDebugSession session, BuildContext context) {
    final mode = session.flutterMode;
    final isDebug = mode == 'debug';
    final isProfile = mode == 'profile';
    final isRelease = mode == 'release' || mode == 'jit_release';
    final isFlutter = session.debuggerType?.contains('Flutter') ?? false;
    final isWeb = devices[session.flutterDeviceId]?.platformType == 'web';

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
          onPressed: editor.supportsHotReload && (isDebug || !isFlutter)
              ? () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.hotReload,
                  );
                  unawaited(editor.hotReload(session.id));
                }
              : null,
          tooltip: 'Hot Reload',
          icon: Icon(hotReloadIcon, size: actionsIconSize),
        ),
        IconButton(
          onPressed: editor.supportsHotRestart && (isDebug || !isFlutter)
              ? () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.hotRestart,
                  );
                  unawaited(editor.hotRestart(session.id));
                }
              : null,
          tooltip: 'Hot Restart',
          icon: Icon(hotRestartIcon, size: actionsIconSize),
        ),
        // TODO(kenz): remove DevTools menu when we runtime extensions are
        // available from the DevTools extensions section.
        if (editor.supportsOpenDevToolsPage)
          _DevToolsMenu(
            editor: editor,
            session: session,
            isFlutter: isFlutter,
            isDebug: isDebug,
            isProfile: isProfile,
            isRelease: isRelease,
            isWeb: isWeb,
            supportsOpenExternal: editor.supportsOpenDevToolsExternally,
          ),
      ],
    );
  }
}

class _DevToolsMenu extends StatefulWidget {
  const _DevToolsMenu({
    required this.editor,
    required this.session,
    required this.isFlutter,
    required this.isDebug,
    required this.isProfile,
    required this.isRelease,
    required this.isWeb,
    required this.supportsOpenExternal,
  });

  final EditorClient editor;
  final EditorDebugSession session;
  final bool isFlutter;
  final bool isDebug;
  final bool isProfile;
  final bool isRelease;
  final bool isWeb;
  final bool supportsOpenExternal;

  @override
  State<_DevToolsMenu> createState() => _DevToolsMenuState();
}

class _DevToolsMenuState extends State<_DevToolsMenu> {
  ExtensionService? _extensionServiceForSession;

  @override
  void initState() {
    super.initState();
    _initExtensions();
  }

  void _initExtensions() {
    final sessionRootPath = widget.session.projectRootPath;
    if (sessionRootPath != null) {
      // This file path might be a Windows path but because this code runs in
      // the web, Uri.file() will not handle it correctly.
      //
      // Since all paths are absolute, assume that if the path contains `\` and
      // not `/` then it's Windows.
      final isWindows =
          sessionRootPath.contains(r'\') && !sessionRootPath.contains(r'/');
      final fileUri = Uri.file(sessionRootPath, windows: isWindows);
      assert(fileUri.isScheme('file'));
      _extensionServiceForSession = ExtensionService(
        fixedAppRoot: fileUri,
        ignoreServiceConnection: true,
      );
      unawaited(_extensionServiceForSession!.initialize());
    }
  }

  @override
  void didUpdateWidget(_DevToolsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _extensionServiceForSession?.dispose();
      _initExtensions();
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
          unawaited(
            widget.editor.openDevToolsPage(
              widget.session.id,
              page: screen.id,
            ),
          );
        },
      );
    }

    return MenuAnchor(
      menuChildren: [
        ...ScreenMetaData.values
            .where(_shouldIncludeScreen)
            .map(devToolsButton),
        if (widget.supportsOpenExternal)
          DevToolsScreenMenuItem(
            title: 'Open in Browser',
            icon: Icons.open_in_browser,
            onPressed: () {
              ga.select(
                gac.VsCodeFlutterSidebar.id,
                gac.VsCodeFlutterSidebar.openDevToolsExternally.name,
              );
              unawaited(
                widget.editor.openDevToolsPage(
                  widget.session.id,
                  forceExternal: true,
                ),
              );
            },
          ),
        if (_extensionServiceForSession != null)
          ValueListenableBuilder(
            valueListenable: _extensionServiceForSession!.currentExtensions,
            builder: (context, currentExtensions, _) {
              return currentExtensions.visibleExtensions.isEmpty
                  ? const SizedBox.shrink()
                  : ExtensionScreenMenuItem(
                      extensions: currentExtensions.visibleExtensions,
                      onPressed: (e) {
                        ga.select(
                          gac.VsCodeFlutterSidebar.id,
                          gac.VsCodeFlutterSidebar.openDevToolsScreen(
                            gac.DevToolsExtensionEvents.extensionScreenName(
                              e,
                            ),
                          ),
                        );
                        unawaited(
                          widget.editor.openDevToolsPage(
                            widget.session.id,
                            page: e.screenId,
                          ),
                        );
                      },
                    );
            },
          ),
      ],
      builder: (context, controller, child) => IconButton(
        onPressed: widget.isRelease
            ? null
            : () {
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

/// A context menu item for an individual DevTools screen.
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

/// A context menu submenu button that contains the list of available extension
/// screens.
class ExtensionScreenMenuItem extends StatelessWidget {
  const ExtensionScreenMenuItem({
    super.key,
    required this.extensions,
    required this.onPressed,
  });

  static const _submenuOffsetDy = 8.0;

  final List<DevToolsExtensionConfig> extensions;

  final void Function(DevToolsExtensionConfig) onPressed;

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      alignmentOffset: const Offset(0.0, _submenuOffsetDy),
      menuChildren: extensions
          .map(
            (e) => DevToolsScreenMenuItem(
              title: e.name,
              icon: e.icon,
              onPressed: () => onPressed(e),
            ),
          )
          .toList(),
      child: const Text('Extensions'),
    );
  }
}

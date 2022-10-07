// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../primitives/listenable.dart';
import 'globals.dart';
import 'theme.dart';
import 'version.dart';

/// Defines a page shown in the DevTools [TabBar].
@immutable
abstract class Screen {
  const Screen(
    this.screenId, {
    this.title = '',
    this.icon,
    this.tabKey,
    this.requiresLibrary,
    this.requiresDartVm = false,
    this.requiresDebugBuild = false,
    this.requiresVmDeveloperMode = false,
    this.worksOffline = false,
    this.shouldShowForFlutterVersion,
    this.showFloatingDebuggerControls = true,
  });

  const Screen.conditional({
    required String id,
    String? requiresLibrary,
    bool requiresDartVm = false,
    bool requiresDebugBuild = false,
    bool requiresVmDeveloperMode = false,
    bool worksOffline = false,
    bool Function(FlutterVersion? currentVersion)? shouldShowForFlutterVersion,
    bool showFloatingDebuggerControls = true,
    String title = '',
    IconData? icon,
    Key? tabKey,
  }) : this(
          id,
          requiresLibrary: requiresLibrary,
          requiresDartVm: requiresDartVm,
          requiresDebugBuild: requiresDebugBuild,
          requiresVmDeveloperMode: requiresVmDeveloperMode,
          worksOffline: worksOffline,
          shouldShowForFlutterVersion: shouldShowForFlutterVersion,
          showFloatingDebuggerControls: showFloatingDebuggerControls,
          title: title,
          icon: icon,
          tabKey: tabKey,
        );

  /// Whether to show floating debugger controls if the app is paused.
  ///
  /// If your page is negatively impacted by the app being paused you should
  /// show debugger controls.
  final bool showFloatingDebuggerControls;

  /// Whether to show the console for this screen.
  bool showConsole(bool embed) => false;

  /// Which keyboard shortcuts should be enabled for this screen.
  ShortcutsConfiguration buildKeyboardShortcuts(BuildContext context) =>
      ShortcutsConfiguration.empty();

  final String screenId;

  /// The user-facing name of the page.
  final String title;

  final IconData? icon;

  /// An optional key to use when creating the Tab widget (for use during
  /// testing).
  final Key? tabKey;

  /// Library uri that determines whether to include this screen in DevTools.
  ///
  /// This can either be a full library uri or it can be a prefix. If null, this
  /// screen will be shown if it meets all other criteria.
  ///
  /// Examples:
  ///  * 'package:provider/provider.dart'
  ///  * 'package:provider/'
  final String? requiresLibrary;

  /// Whether this screen should only be included when the app is running on the Dart VM.
  final bool requiresDartVm;

  /// Whether this screen should only be included when the app is debuggable.
  final bool requiresDebugBuild;

  /// Whether this screen should only be included when VM developer mode is enabled.
  final bool requiresVmDeveloperMode;

  /// Whether this screen works offline and should show in offline mode even if conditions are not met.
  final bool worksOffline;

  /// A callback that will determine whether or not this screen should be
  /// available for a given flutter version.
  final bool Function(FlutterVersion? currentFlutterVersion)?
      shouldShowForFlutterVersion;

  /// Whether this screen should display the isolate selector in the status
  /// line.
  ///
  /// Some screens act on all isolates; for these screens, displaying a
  /// selector doesn't make sense.
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(false);

  /// The id to use to synthesize a help URL.
  ///
  /// If the screen does not have a custom documentation page, this property
  /// should return `null`.
  String? get docPageId => null;

  int get badgeCount => 0;

  double approximateWidth(TextTheme textTheme) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: textTheme.bodyLarge,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + denseSpacing + defaultIconSize + defaultSpacing * 2;
  }

  /// Builds the tab to show for this screen in the [DevToolsScaffold]'s main
  /// navbar.
  ///
  /// This will not be used if the [Screen] is the only one shown in the
  /// scaffold.
  Widget buildTab(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable:
          serviceManager.errorBadgeManager.errorCountNotifier(screenId),
      builder: (context, count, _) {
        final tab = Tab(
          key: tabKey,
          child: Row(
            children: <Widget>[
              Icon(icon, size: defaultIconSize),
              Padding(
                padding: const EdgeInsets.only(left: denseSpacing),
                child: Text(title),
              ),
            ],
          ),
        );

        if (count > 0) {
          // Calculate the width of the title text so that we can provide an accurate
          // size for the [BadgePainter]
          final painter = TextPainter(
            text: TextSpan(
              text: title,
              style: Theme.of(context).regularTextStyle,
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final titleWidth = painter.width;

          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  CustomPaint(
                    size: Size(defaultIconSize + denseSpacing + titleWidth, 0),
                    painter: BadgePainter(number: count),
                  ),
                  tab,
                ],
              );
            },
          );
        }

        return tab;
      },
    );
  }

  /// Builds the body to display for this tab.
  Widget build(BuildContext context);

  /// Build a widget to display in the status line.
  ///
  /// If this method returns `null`, then no page specific status is displayed.
  Widget? buildStatus(BuildContext context) {
    return null;
  }
}

mixin OfflineScreenMixin<T extends StatefulWidget, U> on State<T> {
  bool get loadingOfflineData => _loadingOfflineData;
  bool _loadingOfflineData = false;

  bool shouldLoadOfflineData();

  FutureOr<void> processOfflineData(U offlineData);

  Future<void> loadOfflineData(U offlineData) async {
    setState(() {
      _loadingOfflineData = true;
    });
    await processOfflineData(offlineData);
    setState(() {
      _loadingOfflineData = false;
    });
  }
}

/// Check whether a screen should be shown in the UI.
bool shouldShowScreen(Screen screen) {
  if (offlineController.offlineMode.value) {
    return screen.worksOffline;
  }
  // No sense in ever showing screens in non-offline mode unless the service
  // is available. This also avoids odd edge cases where we could show screens
  // while the ServiceManager is still initializing.
  if (!serviceManager.isServiceAvailable ||
      !serviceManager.connectedApp!.connectedAppInitialized) return false;

  if (screen.requiresLibrary != null) {
    if (serviceManager.isolateManager.mainIsolate.value == null ||
        !serviceManager.libraryUriAvailableNow(screen.requiresLibrary)) {
      return false;
    }
  }
  if (screen.requiresDartVm) {
    if (serviceManager.connectedApp!.isRunningOnDartVM != true) {
      return false;
    }
  }
  if (screen.requiresDebugBuild) {
    if (serviceManager.connectedApp!.isProfileBuildNow == true) {
      return false;
    }
  }
  if (screen.requiresVmDeveloperMode) {
    if (!preferences.vmDeveloperModeEnabled.value) {
      return false;
    }
  }
  if (screen.shouldShowForFlutterVersion != null) {
    if (serviceManager.connectedApp!.isFlutterAppNow == true &&
        !screen.shouldShowForFlutterVersion!(
          serviceManager.connectedApp!.flutterVersionNow,
        )) {
      return false;
    }
  }
  return true;
}

class BadgePainter extends CustomPainter {
  BadgePainter({required this.number});

  final int number;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = devtoolsError
      ..style = PaintingStyle.fill;

    final countPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = math.max(
      defaultIconSize,
      countPainter.width + denseSpacing,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width, 0, badgeWidth, defaultIconSize),
      paint,
    );

    countPainter.paint(
      canvas,
      Offset(size.width + (badgeWidth - countPainter.width) / 2, 0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is BadgePainter) {
      return number != oldDelegate.number;
    }
    return true;
  }
}

class ShortcutsConfiguration {
  const ShortcutsConfiguration({
    required this.shortcuts,
    required this.actions,
  }) : assert(shortcuts.length == actions.length);

  factory ShortcutsConfiguration.empty() {
    return ShortcutsConfiguration(shortcuts: {}, actions: {});
  }

  final Map<ShortcutActivator, Intent> shortcuts;
  final Map<Type, Action<Intent>> actions;

  bool get isEmpty => shortcuts.isEmpty && actions.isEmpty;
}

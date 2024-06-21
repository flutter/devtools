// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'feature_flags.dart';
import 'globals.dart';
import 'primitives/listenable.dart';
import 'ui/icons.dart';

final _log = Logger('screen.dart');

enum ScreenMetaData {
  home(
    'home',
    icon: Icons.home_rounded,
    requiresConnection: false,
    tutorialVideoTimestamp: '?t=0',
  ),
  inspector(
    'inspector',
    title: 'Flutter Inspector',
    icon: Octicons.deviceMobile,
    requiresFlutter: true,
    requiresDebugBuild: true,
    tutorialVideoTimestamp: '?t=172',
  ),
  performance(
    'performance',
    title: 'Performance',
    icon: Octicons.pulse,
    worksWithOfflineData: true,
    requiresConnection: false,
    tutorialVideoTimestamp: '?t=261',
  ),
  cpuProfiler(
    'cpu-profiler',
    title: 'CPU Profiler',
    icon: Octicons.dashboard,
    requiresDartVm: true,
    worksWithOfflineData: true,
    requiresConnection: false,
    tutorialVideoTimestamp: '?t=340',
  ),
  memory(
    'memory',
    title: 'Memory',
    icon: Octicons.package,
    requiresDartVm: true,
    // ignore: avoid_redundant_argument_values, false positive
    requiresConnection: !FeatureFlags.memoryOffline,
    tutorialVideoTimestamp: '?t=420',
    // ignore: avoid_redundant_argument_values, false positive
    worksWithOfflineData: FeatureFlags.memoryOffline,
  ),
  debugger(
    'debugger',
    title: 'Debugger',
    icon: Octicons.bug,
    requiresDebugBuild: true,
    tutorialVideoTimestamp: '?t=513',
  ),
  network(
    'network',
    title: 'Network',
    icon: Icons.network_check,
    requiresDartVm: true,
    tutorialVideoTimestamp: '?t=547',
  ),
  logging(
    'logging',
    title: 'Logging',
    icon: Octicons.clippy,
    tutorialVideoTimestamp: '?t=558',
  ),
  provider(
    'provider',
    title: 'Provider',
    icon: Icons.attach_file,
    requiresLibrary: 'package:provider/',
    requiresDebugBuild: true,
  ),
  appSize(
    'app-size',
    title: 'App Size',
    icon: Octicons.fileZip,
    requiresConnection: false,
    requiresDartVm: true,
    tutorialVideoTimestamp: '?t=575',
  ),
  deepLinks(
    'deep-links',
    title: 'Deep Links',
    icon: Icons.link_rounded,
    requiresConnection: false,
    requiresDartVm: true,
  ),
  vmTools(
    'vm-tools',
    title: 'VM Tools',
    icon: Icons.settings_applications,
    requiresVmDeveloperMode: true,
  ),
  simple('simple');

  const ScreenMetaData(
    this.id, {
    this.title,
    this.icon,
    this.requiresConnection = true,
    this.requiresDartVm = false,
    this.requiresFlutter = false,
    this.requiresDebugBuild = false,
    this.requiresVmDeveloperMode = false,
    this.worksWithOfflineData = false,
    this.requiresLibrary,
    this.tutorialVideoTimestamp,
  });

  final String id;
  final String? title;
  final IconData? icon;
  final bool requiresConnection;
  final bool requiresDartVm;
  final bool requiresFlutter;
  final bool requiresDebugBuild;
  final bool requiresVmDeveloperMode;
  final bool worksWithOfflineData;
  final String? requiresLibrary;

  /// The timestamp for the chapter of "Dive in to DevTools" YouTube video that
  /// correlates to a screen.
  ///
  /// This value will be appended to "https://youtu.be/_EYk-E29edo" to link to
  /// a particular chapter.
  final String? tutorialVideoTimestamp;

  /// Looks up the [ScreenMetaData] value for the screen [id].
  static ScreenMetaData? lookup(String id) {
    return ScreenMetaData.values.firstWhereOrNull((screen) => screen.id == id);
  }
}

/// Defines a page shown in the DevTools [TabBar].
///
/// A devtools screen can be in three modes:
/// * offline-data
/// * connected
/// * not-connected
///
/// See [devToolsMode].
///
/// A screen may support any combination of modes.
///
/// For offline-data and connected modes:
/// * Override [Screen.buildScreenBody] to build content.
/// * Use [ProvidedControllerMixin] to access controller.
/// * See [OfflineScreenControllerMixin] for documentation on how to
/// enable and handle offline-data mode for a screen.
///
/// For not-connected mode:
/// * Override [Screen.buildDisconnectedScreenBody] to build content.
/// * Set [ScreenMetaData.requiresConnection] to false.
@immutable
abstract class Screen {
  const Screen(
    this.screenId, {
    this.title,
    this.titleGenerator,
    this.icon,
    this.tabKey,
    this.requiresLibrary,
    this.requiresConnection = true,
    this.requiresDartVm = false,
    this.requiresFlutter = false,
    this.requiresDebugBuild = false,
    this.requiresVmDeveloperMode = false,
    this.worksWithOfflineData = false,
    this.showFloatingDebuggerControls = true,
  }) : assert((title == null) || (titleGenerator == null));

  const Screen.conditional({
    required String id,
    String? requiresLibrary,
    bool requiresConnection = true,
    bool requiresDartVm = false,
    bool requiresFlutter = false,
    bool requiresDebugBuild = false,
    bool requiresVmDeveloperMode = false,
    bool worksWithOfflineData = false,
    bool Function(FlutterVersion? currentVersion)? shouldShowForFlutterVersion,
    bool showFloatingDebuggerControls = true,
    String? title,
    String Function()? titleGenerator,
    IconData? icon,
    Key? tabKey,
  }) : this(
          id,
          requiresLibrary: requiresLibrary,
          requiresConnection: requiresConnection,
          requiresDartVm: requiresDartVm,
          requiresFlutter: requiresFlutter,
          requiresDebugBuild: requiresDebugBuild,
          requiresVmDeveloperMode: requiresVmDeveloperMode,
          worksWithOfflineData: worksWithOfflineData,
          showFloatingDebuggerControls: showFloatingDebuggerControls,
          title: title,
          titleGenerator: titleGenerator,
          icon: icon,
          tabKey: tabKey,
        );

  Screen.fromMetaData(
    ScreenMetaData metadata, {
    bool Function(FlutterVersion? currentVersion)? shouldShowForFlutterVersion,
    bool showFloatingDebuggerControls = true,
    String Function()? titleGenerator,
    Key? tabKey,
  }) : this.conditional(
          id: metadata.id,
          requiresLibrary: metadata.requiresLibrary,
          requiresConnection: metadata.requiresConnection,
          requiresDartVm: metadata.requiresDartVm,
          requiresFlutter: metadata.requiresFlutter,
          requiresDebugBuild: metadata.requiresDebugBuild,
          requiresVmDeveloperMode: metadata.requiresVmDeveloperMode,
          worksWithOfflineData: metadata.worksWithOfflineData,
          shouldShowForFlutterVersion: shouldShowForFlutterVersion,
          showFloatingDebuggerControls: showFloatingDebuggerControls,
          title: titleGenerator == null ? metadata.title : null,
          titleGenerator: titleGenerator,
          icon: metadata.icon,
          tabKey: tabKey,
        );

  /// Whether to show floating debugger controls if the app is paused.
  ///
  /// If your page is negatively impacted by the app being paused you should
  /// show debugger controls.
  final bool showFloatingDebuggerControls;

  /// Whether to show the console for this screen.
  bool showConsole(EmbedMode embedMode) => false;

  /// Which keyboard shortcuts should be enabled for this screen.
  ShortcutsConfiguration buildKeyboardShortcuts(BuildContext context) =>
      ShortcutsConfiguration.empty();

  final String screenId;

  /// The user-facing name of the page.
  ///
  /// At most, only one of [title] and [titleGenerator] should be non-null.
  final String? title;

  /// A callback that returns the user-facing name of the page.
  ///
  /// At most, only one of [title] and [titleGenerator] should be non-null.
  final String Function()? titleGenerator;

  String get _userFacingTitle => title ?? titleGenerator?.call() ?? '';

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

  /// Whether this screen requires a running app connection to work.
  final bool requiresConnection;

  /// Whether this screen should only be included when the app is running on the Dart VM.
  final bool requiresDartVm;

  /// Whether this screen should only be included when the app is a Flutter app.
  final bool requiresFlutter;

  /// Whether this screen should only be included when the app is debuggable.
  final bool requiresDebugBuild;

  /// Whether this screen should only be included when VM developer mode is enabled.
  final bool requiresVmDeveloperMode;

  /// Whether this screen works offline and should show in offline mode even if conditions are not met.
  final bool worksWithOfflineData;

  /// Whether this screen should display the isolate selector in the status
  /// line.
  ///
  /// Some screens act on all isolates; for these screens, displaying a
  /// selector doesn't make sense.
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(false);

  /// The documentation URL to use for this screen.
  ///
  /// If this returns a null value, [docPageId] will be used to create a
  /// documentation URL.
  String? get docsUrl => null;

  /// The id to use to create a documentation URL for this screen.
  ///
  /// If the screen does not have a custom documentation page, this property
  /// should return `null`.
  ///
  /// If [docsUrl] returns a non-null value, [docsUrl] will be used instead of
  /// creating a documentation url using [docPageId].
  String? get docPageId => null;

  double approximateTabWidth(
    TextTheme textTheme, {
    bool includeTabBarSpacing = true,
  }) {
    final title = _userFacingTitle;
    final painter = TextPainter(
      text: TextSpan(text: title),
      textDirection: TextDirection.ltr,
    )..layout();
    const measurementBuffer = 2.0;
    return painter.width +
        denseSpacing +
        defaultIconSize +
        (includeTabBarSpacing ? tabBarSpacing * 2 : 0.0) +
        // Add a small buffer to account for variances between the text painter
        // approximation and the actual measurement.
        measurementBuffer;
  }

  /// Builds the tab to show for this screen in the [DevToolsScaffold]'s main
  /// navbar.
  ///
  /// This will not be used if the [Screen] is the only one shown in the
  /// scaffold.
  Widget buildTab(BuildContext context) {
    final title = _userFacingTitle;
    return ValueListenableBuilder<int>(
      valueListenable:
          serviceConnection.errorBadgeManager.errorCountNotifier(screenId),
      builder: (context, count, _) {
        final tab = Tab(
          key: tabKey,
          child: Row(
            children: <Widget>[
              Icon(icon, size: defaultIconSize),
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: denseSpacing),
                  child: Text(
                    title,
                    style: Theme.of(context).regularTextStyle,
                  ),
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
                    painter: BadgePainter(
                      number: count,
                      colorScheme: Theme.of(context).colorScheme,
                    ),
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

  /// Builds the body to display for this screen, accounting for screen
  /// requirements like [requiresConnection].
  ///
  /// This method can be overridden to provide different build logic for a
  /// [Screen] subclass.
  Widget build(BuildContext context) {
    if (!requiresConnection) {
      final connected = serviceConnection.serviceManager.hasConnection &&
          serviceConnection.serviceManager.connectedAppInitialized;
      // Do not use the disconnected body in offline mode, because the default
      // [buildScreenBody] should be used for offline states.
      if (!connected && !offlineDataController.showingOfflineData.value) {
        final disconnectedBody = buildDisconnectedScreenBody(context);
        if (disconnectedBody != null) return disconnectedBody;
      }
    }
    return buildScreenBody(context);
  }

  /// Builds the default body to display for this screen.
  ///
  /// This method must be implemented by subclasses.
  Widget buildScreenBody(BuildContext context);

  /// Builds the body to display for this screen when in a disconnected state,
  /// if this differs from the default body provided by [buildScreenBody].
  ///
  /// This method will only be called when [requiresConnection] is not true,
  /// and when DevTools is in a disconnected state.
  Widget? buildDisconnectedScreenBody(BuildContext context) => null;

  /// Build a widget to display in the status line.
  ///
  /// If this method returns `null`, then no page specific status is displayed.
  Widget? buildStatus(BuildContext context) {
    return null;
  }
}

/// Check whether a screen should be shown in the UI.
({bool show, ScreenDisabledReason? disabledReason}) shouldShowScreen(
  Screen screen,
) {
  _log.finest('shouldShowScreen: ${screen.screenId}');
  if (offlineDataController.showingOfflineData.value) {
    _log.finest('for offline mode: returning ${screen.worksWithOfflineData}');
    return (
      show: screen.worksWithOfflineData,
      disabledReason: screen.worksWithOfflineData
          ? null
          : ScreenDisabledReason.offlineDataNotSupported,
    );
  }

  final serviceReady = serviceConnection.serviceManager.isServiceAvailable &&
      serviceConnection.serviceManager.connectedApp!.connectedAppInitialized;
  if (!serviceReady) {
    if (!screen.requiresConnection) {
      _log.finest('screen does not require connection: returning true');
      return (show: true, disabledReason: null);
    } else {
      // All of the following checks require a connected vm service, so verify
      // that one exists. This also avoids odd edge cases where we could show
      // screens while the ServiceManager is still initializing.
      _log.finest('service not ready: returning false');
      return (
        show: false,
        disabledReason: ScreenDisabledReason.serviceNotReady,
      );
    }
  }

  if (screen.requiresLibrary != null) {
    if (serviceConnection.serviceManager.isolateManager.mainIsolate.value ==
            null ||
        !serviceConnection.serviceManager
            .libraryUriAvailableNow(screen.requiresLibrary)) {
      _log.finest(
        'screen requires library ${screen.requiresLibrary}: returning false',
      );
      return (
        show: false,
        disabledReason: ScreenDisabledReason.requiresDartLibrary,
      );
    }
  }
  if (screen.requiresDartVm) {
    if (serviceConnection.serviceManager.connectedApp!.isRunningOnDartVM !=
        true) {
      _log.finest('screen requires Dart VM: returning false');
      return (show: false, disabledReason: ScreenDisabledReason.requiresDartVm);
    }
  }
  if (screen.requiresFlutter &&
      serviceConnection.serviceManager.connectedApp!.isFlutterAppNow == false) {
    _log.finest('screen requires Flutter: returning false');
    return (show: false, disabledReason: ScreenDisabledReason.requiresFlutter);
  }
  if (screen.requiresDebugBuild) {
    if (serviceConnection.serviceManager.connectedApp!.isProfileBuildNow ==
        true) {
      _log.finest('screen requires debug build: returning false');
      return (
        show: false,
        disabledReason: ScreenDisabledReason.requiresDebugBuild,
      );
    }
  }
  if (screen.requiresVmDeveloperMode) {
    if (!preferences.vmDeveloperModeEnabled.value) {
      _log.finest('screen requires vm developer mode: returning false');
      return (
        show: false,
        disabledReason: ScreenDisabledReason.requiresVmDeveloperMode,
      );
    }
  }
  _log.finest('${screen.screenId} screen supported: returning true');
  return (show: true, disabledReason: null);
}

class BadgePainter extends CustomPainter {
  BadgePainter({required this.number, required this.colorScheme});

  final ColorScheme colorScheme;

  final int number;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.errorContainer
      ..style = PaintingStyle.fill;

    final countPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: colorScheme.onErrorContainer,
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

enum ScreenDisabledReason {
  offlineDataNotSupported('does not support offline data.'),
  requiresDartLibrary(null),
  requiresDartVm('requires the Dart VM, but it is not available.'),
  requiresDebugBuild('only supports debug builds.'),
  requiresFlutter('only supports Flutter applications.'),
  requiresVmDeveloperMode('only works when VM Developer Mode is enabled'),
  serviceNotReady('requires a connection but the VM service is not ready.');

  const ScreenDisabledReason(this.message);

  final String? message;
}

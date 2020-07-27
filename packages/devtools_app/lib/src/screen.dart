// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import 'globals.dart';
import 'scaffold.dart';
import 'theme.dart';

/// Defines a page shown in the DevTools [TabBar].
@immutable
abstract class Screen {
  const Screen(
    this.screenId, {
    this.title,
    this.icon,
    this.tabKey,
    this.requiresLibrary,
    this.requiresDartVm = false,
    this.requiresDebugBuild = false,
    this.worksOffline = false,
  });

  const Screen.conditional({
    @required String id,
    String requiresLibrary,
    bool requiresDartVm = false,
    bool requiresDebugBuild = false,
    bool worksOffline = false,
    String title,
    IconData icon,
    Key tabKey,
  }) : this(
          id,
          requiresLibrary: requiresLibrary,
          requiresDartVm: requiresDartVm,
          requiresDebugBuild: requiresDebugBuild,
          worksOffline: worksOffline,
          title: title,
          icon: icon,
          tabKey: tabKey,
        );

  final String screenId;

  /// The user-facing name of the page.
  final String title;

  final IconData icon;

  /// An optional key to use when creating the Tab widget (for use during
  /// testing).
  final Key tabKey;

  /// Library uri that determines whether to include this screen in DevTools.
  ///
  /// This can either be a full library uri or it can be a prefix. If null, this
  /// screen will be shown if it meets all other criteria.
  ///
  /// Examples:
  ///  * 'package:provider/provider.dart'
  ///  * 'package:provider/'
  final String requiresLibrary;

  /// Whether this screen should only be included when the app is running on the Dart VM.
  final bool requiresDartVm;

  /// Whether this screen should only be included when the app is debuggable.
  final bool requiresDebugBuild;

  /// Whether this screen works offline and should show in offline mode even if conditions are not met.
  final bool worksOffline;

  /// Whether this screen should display the isolate selector in the status
  /// line.
  ///
  /// Some screens act on all isolates; for these screens, displaying a
  /// selector doesn't make sense.
  bool get showIsolateSelector => false;

  /// The id to use to synthesize a help URL.
  ///
  /// If the screen does not have a custom documentation page, this property
  /// should return `null`.
  String get docPageId => null;

  /// Builds the tab to show for this screen in the [DevToolsScaffold]'s main
  /// navbar.
  ///
  /// This will not be used if the [Screen] is the only one shown in the
  /// scaffold.
  Widget buildTab(BuildContext context) {
    return Tab(
      key: tabKey,
      child: Row(
        children: <Widget>[
          Icon(icon, size: defaultIconSize),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(title),
          ),
        ],
      ),
    );
  }

  /// Builds the body to display for this tab.
  Widget build(BuildContext context);

  /// Build a widget to display in the status line.
  ///
  /// If this method returns `null`, then no page specific status is displayed.
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
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
  if (offlineMode) {
    return screen.worksOffline;
  }
  if (screen.requiresLibrary != null) {
    if (!serviceManager.isServiceAvailable ||
        !serviceManager.isolateManager.selectedIsolateAvailable.isCompleted ||
        !serviceManager.libraryUriAvailableNow(screen.requiresLibrary)) {
      return false;
    }
  }
  if (screen.requiresDartVm) {
    if (!serviceManager.isServiceAvailable ||
        !serviceManager.connectedApp.isRunningOnDartVM) {
      return false;
    }
  }
  if (screen.requiresDebugBuild) {
    if (!serviceManager.isServiceAvailable ||
        serviceManager.connectedApp.isProfileBuildNow) {
      return false;
    }
  }
  return true;
}

// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../analytics/constants.dart' as analytics_constants;
import '../shared/theme.dart';
import '../ui/icons.dart';

class RegisteredServiceDescription extends RegisteredService {
  const RegisteredServiceDescription._({
    required String service,
    required String title,
    this.icon,
    this.gaScreenName,
    this.gaItem,
  }) : super(service: service, title: title);

  final Widget? icon;
  final String? gaScreenName;
  final String? gaItem;
}

/// Hot reload service registered by Flutter Tools.
///
/// We call this service to perform hot reload.
final hotReload = RegisteredServiceDescription._(
  service: 'reloadSources',
  title: 'Hot Reload',
  icon: AssetImageIcon(
    asset: 'icons/hot-reload-white@2x.png',
    height: actionsIconSize,
    width: actionsIconSize,
  ),
  gaScreenName: analytics_constants.devToolsMain,
  gaItem: analytics_constants.hotReload,
);

/// Hot restart service registered by Flutter Tools.
///
/// We call this service to perform a hot restart.
final hotRestart = RegisteredServiceDescription._(
  service: 'hotRestart',
  title: 'Hot Restart',
  icon: Icon(
    Icons.settings_backup_restore,
    size: actionsIconSize,
  ),
  gaScreenName: analytics_constants.devToolsMain,
  gaItem: analytics_constants.hotRestart,
);

/// Flutter version service registered by Flutter Tools.
///
/// We call this service to get version information about the Flutter framework,
/// the Flutter engine, and the Dart sdk.
const flutterVersion = RegisteredService(
  service: 'flutterVersion',
  title: 'Flutter Version',
);

RegisteredService get flutterMemoryInfo => flutterMemory;

const flutterListViews = '_flutter.listViews';

const displayRefreshRate = '_flutter.getDisplayRefreshRate';

String get flutterEngineEstimateRasterCache => flutterEngineRasterCache;

/// Dwds listens to events for recording end-to-end analytics.
const dwdsSendEvent = 'ext.dwds.sendEvent';

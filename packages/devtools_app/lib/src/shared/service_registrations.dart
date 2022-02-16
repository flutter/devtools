// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:flutter/material.dart';

import '../analytics/constants.dart' as analytics_constants;
import '../ui/icons.dart';
import 'theme.dart';

class RegisteredServiceDescription {
  const RegisteredServiceDescription._({
    required this.service,
    required this.title,
    this.icon,
    this.gaScreenName,
    this.gaItem,
  });

  final String service;
  final String title;
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
const flutterVersion = RegisteredServiceDescription._(
  service: 'flutterVersion',
  title: 'Flutter Version',
);

/// Flutter memory service registered by Flutter Tools.
///
/// We call this service to get version information about the Flutter Android
/// memory info using Android's ADB.
const flutterMemory = RegisteredServiceDescription._(
  service: 'flutterMemoryInfo',
  title: 'Flutter Memory Info',
);

const flutterListViews = '_flutter.listViews';

const displayRefreshRate = '_flutter.getDisplayRefreshRate';

/// Flutter engine returns estimate how much memory is used by layer/picture raster
/// cache entries in bytes.
const flutterEngineEstimateRasterCache = '_flutter.estimateRasterCacheMemory';

/// Dwds listens to events for recording end-to-end analytics.
const dwdsSendEvent = 'ext.dwds.sendEvent';

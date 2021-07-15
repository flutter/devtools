// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui/icons.dart';

class RegisteredServiceDescription {
  const RegisteredServiceDescription._({
    this.service,
    this.title,
    this.icon,
  });

  final String service;
  final String title;
  final Widget icon;
}

/// Hot reload service registered by Flutter Tools.
///
/// We call this service to perform hot reload.
const hotReload = RegisteredServiceDescription._(
  service: 'reloadSources',
  title: 'Hot Reload',
  icon: AssetImageIcon(
    asset: 'icons/hot-reload-white@2x.png',
    height: actionsIconSize,
    width: actionsIconSize,
  ),
);

/// Hot restart service registered by Flutter Tools.
///
/// We call this service to perform a hot restart.
const hotRestart = RegisteredServiceDescription._(
  service: 'hotRestart',
  title: 'Hot Restart',
  icon: Icon(
    Icons.settings_backup_restore,
    size: actionsIconSize,
  ),
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

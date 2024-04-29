// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service_extensions.dart' as extensions;
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../shared/analytics/constants.dart' as gac;
import '../shared/constants.dart';

class RegisteredServiceDescription extends RegisteredService {
  const RegisteredServiceDescription._({
    required super.service,
    required super.title,
    this.icon,
    this.gaScreenName,
    this.gaItem,
  });

  final Widget? icon;
  final String? gaScreenName;
  final String? gaItem;
}

/// Hot reload service registered by Flutter Tools.
///
/// We call this service to perform hot reload.
final hotReload = RegisteredServiceDescription._(
  service: extensions.hotReloadServiceName,
  title: 'Hot Reload',
  icon: Icon(hotReloadIcon, size: actionsIconSize),
  gaScreenName: gac.devToolsMain,
  gaItem: gac.hotReload,
);

/// Hot restart service registered by Flutter Tools.
///
/// We call this service to perform a hot restart.
final hotRestart = RegisteredServiceDescription._(
  service: extensions.hotRestartServiceName,
  title: 'Hot Restart',
  icon: Icon(hotRestartIcon, size: actionsIconSize),
  gaScreenName: gac.devToolsMain,
  gaItem: gac.hotRestart,
);

RegisteredService get flutterMemoryInfo => flutterMemory;

const flutterListViews = '_flutter.listViews';

const displayRefreshRate = '_flutter.getDisplayRefreshRate';

String get flutterEngineEstimateRasterCache => flutterEngineRasterCache;

const renderFrameWithRasterStats = '_flutter.renderFrameWithRasterStats';

/// Dwds listens to events for recording end-to-end analytics.
const dwdsSendEvent = 'ext.dwds.sendEvent';

/// Service extension that returns whether or not the Impeller rendering engine
/// is being used (if false, the app is using SKIA).
const isImpellerEnabled = 'ext.ui.window.impellerEnabled';

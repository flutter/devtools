// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_shared/src/deeplink/deeplink_manager.dart';

class FakeDeeplinkManager extends DeeplinkManager {
  String? receivedPath;
  String? receivedBuildVariant;
  String? receivedConfiguration;
  String? receivedTarget;
  late Map<String, Object?> responseForGetAndroidBuildVariants;
  late Map<String, Object?> responseForGetAndroidAppLinkSettings;
  late Map<String, Object?> responseForGetIosBuildOptions;
  late Map<String, Object?> responseForGetIosUniversalLinkSettings;

  @override
  Future<Map<String, Object?>> getAndroidBuildVariants({
    required String rootPath,
    String? ide,
    bool suppressAnalytics = false,
  }) async {
    receivedPath = rootPath;
    return responseForGetAndroidBuildVariants;
  }

  @override
  Future<Map<String, Object?>> getAndroidAppLinkSettings({
    required String rootPath,
    required String buildVariant,
    String? ide,
    bool suppressAnalytics = false,
  }) async {
    receivedPath = rootPath;
    receivedBuildVariant = buildVariant;
    return responseForGetAndroidAppLinkSettings;
  }

  @override
  Future<Map<String, Object?>> getIosBuildOptions({
    required String rootPath,
    String? ide,
    bool suppressAnalytics = false,
  }) async {
    receivedPath = rootPath;
    return responseForGetIosBuildOptions;
  }

  @override
  Future<Map<String, Object?>> getIosUniversalLinkSettings({
    required String rootPath,
    required String configuration,
    required String target,
    String? ide,
    bool suppressAnalytics = false,
  }) async {
    receivedPath = rootPath;
    receivedConfiguration = configuration;
    receivedTarget = target;
    return responseForGetIosUniversalLinkSettings;
  }
}

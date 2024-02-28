// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/src/deeplink/deeplink_manager.dart';

class FakeDeeplinkManager extends DeeplinkManager {
  String? receivedPath;
  String? receivedBuildVariant;
  String? receivedConfiguration;
  String? receivedTarget;
  late Map<String, String> responseForGetAndroidBuildVariants;
  late Map<String, String> responseForGetAndroidAppLinkSettings;
  late Map<String, String> responseForGetIosBuildOptions;
  late Map<String, String> responseForGetIosUniversalLinkSettings;

  @override
  Future<Map<String, String>> getAndroidBuildVariants({
    required String rootPath,
  }) async {
    receivedPath = rootPath;
    return responseForGetAndroidBuildVariants;
  }

  @override
  Future<Map<String, String>> getAndroidAppLinkSettings({
    required String rootPath,
    required String buildVariant,
  }) async {
    receivedPath = rootPath;
    receivedBuildVariant = buildVariant;
    return responseForGetAndroidAppLinkSettings;
  }

  @override
  Future<Map<String, String>> getIosBuildOptions({
    required String rootPath,
  }) async {
    receivedPath = rootPath;
    return responseForGetIosBuildOptions;
  }

  @override
  Future<Map<String, String>> getIosUniversalLinkSettings({
    required String rootPath,
    required String configuration,
    required String target,
  }) async {
    receivedPath = rootPath;
    receivedConfiguration = configuration;
    receivedTarget = target;
    return responseForGetIosUniversalLinkSettings;
  }
}

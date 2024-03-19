// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

part of 'server.dart';

Future<List<String>> requestAndroidBuildVariants(String path) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: DeeplinkApi.androidBuildVariants,
      queryParameters: {
        DeeplinkApi.deeplinkRootPathPropertyName: path,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      final jsonObject = jsonDecode(resp!.body) as List;
      return jsonObject.map((dynamic item) => item as String).toList();
    } else {
      logWarning(resp, DeeplinkApi.androidBuildVariants);
    }
  }
  return const <String>[];
}

Future<AppLinkSettings> requestAndroidAppLinkSettings(
  String path, {
  required String buildVariant,
}) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: DeeplinkApi.androidAppLinkSettings,
      queryParameters: {
        DeeplinkApi.deeplinkRootPathPropertyName: path,
        DeeplinkApi.androidBuildVariantPropertyName: buildVariant,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      return AppLinkSettings.fromJson(resp!.body);
    } else {
      logWarning(resp, DeeplinkApi.androidAppLinkSettings);
    }
  }
  return AppLinkSettings.empty;
}

Future<XcodeBuildOptions> requestIosBuildOptions(String path) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: DeeplinkApi.iosBuildOptions,
      queryParameters: {
        DeeplinkApi.deeplinkRootPathPropertyName: path,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      return XcodeBuildOptions.fromJson(resp!.body);
    } else {
      logWarning(resp, DeeplinkApi.iosBuildOptions);
    }
  }
  return XcodeBuildOptions.empty;
}

Future<UniversalLinkSettings> requestIosUniversalLinkSettings(
  String path, {
  required String configuration,
  required String target,
}) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: DeeplinkApi.iosUniversalLinkSettings,
      queryParameters: {
        DeeplinkApi.deeplinkRootPathPropertyName: path,
        DeeplinkApi.xcodeConfigurationPropertyName: configuration,
        DeeplinkApi.xcodeTargetPropertyName: target,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      return UniversalLinkSettings.fromJson(resp!.body);
    } else {
      logWarning(resp, DeeplinkApi.iosUniversalLinkSettings);
    }
  }
  return UniversalLinkSettings.empty;
}

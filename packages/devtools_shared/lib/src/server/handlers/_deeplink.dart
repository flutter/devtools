// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _DeeplinkApiHandler {
  static Future<shelf.Response> handleAndroidBuildVariants(
    ServerApi api,
    Map<String, String> queryParams,
    DeeplinkManager deeplinkManager,
  ) async {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [DeeplinkApi.deeplinkRootPathPropertyName],
      queryParams: queryParams,
      api: api,
      requestName: DeeplinkApi.androidBuildVariants,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final rootPath = queryParams[DeeplinkApi.deeplinkRootPathPropertyName]!;
    final result =
        await deeplinkManager.getAndroidBuildVariants(rootPath: rootPath);
    return _resultOutputOrError(api, result);
  }

  static Future<shelf.Response> handleAndroidAppLinkSettings(
    ServerApi api,
    Map<String, String> queryParams,
    DeeplinkManager deeplinkManager,
  ) async {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [
        DeeplinkApi.deeplinkRootPathPropertyName,
        DeeplinkApi.androidBuildVariantPropertyName,
      ],
      queryParams: queryParams,
      api: api,
      requestName: DeeplinkApi.androidBuildVariants,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final rootPath = queryParams[DeeplinkApi.deeplinkRootPathPropertyName]!;
    final buildVariant =
        queryParams[DeeplinkApi.androidBuildVariantPropertyName]!;
    final result = await deeplinkManager.getAndroidAppLinkSettings(
      rootPath: rootPath,
      buildVariant: buildVariant,
    );
    return _resultOutputOrError(api, result);
  }

  static Future<shelf.Response> handleIosBuildOptions(
    ServerApi api,
    Map<String, String> queryParams,
    DeeplinkManager deeplinkManager,
  ) async {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [DeeplinkApi.deeplinkRootPathPropertyName],
      queryParams: queryParams,
      api: api,
      requestName: DeeplinkApi.iosBuildOptions,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final rootPath = queryParams[DeeplinkApi.deeplinkRootPathPropertyName]!;
    final result = await deeplinkManager.getIosBuildOptions(rootPath: rootPath);
    return _resultOutputOrError(api, result);
  }

  static Future<shelf.Response> handleIosUniversalLinkSettings(
    ServerApi api,
    Map<String, String> queryParams,
    DeeplinkManager deeplinkManager,
  ) async {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [
        DeeplinkApi.deeplinkRootPathPropertyName,
        DeeplinkApi.xcodeConfigurationPropertyName,
        DeeplinkApi.xcodeTargetPropertyName,
      ],
      queryParams: queryParams,
      api: api,
      requestName: DeeplinkApi.iosUniversalLinkSettings,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final result = await deeplinkManager.getIosUniversalLinkSettings(
      rootPath: queryParams[DeeplinkApi.deeplinkRootPathPropertyName]!,
      configuration: queryParams[DeeplinkApi.xcodeConfigurationPropertyName]!,
      target: queryParams[DeeplinkApi.xcodeTargetPropertyName]!,
    );
    return _resultOutputOrError(api, result);
  }

  static shelf.Response _resultOutputOrError(
    ServerApi api,
    Map<String, Object?> result,
  ) {
    final error = result[DeeplinkManager.kErrorField] as String?;
    if (error != null) {
      return api.serverError(error);
    }
    return api.getCompleted(
      result[DeeplinkManager.kOutputJsonField]! as String,
    );
  }
}

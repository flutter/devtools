// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _ExtensionsApiHandler {
  static Future<shelf.Response> handleServeAvailableExtensions(
    ServerApi api,
    Map<String, String> queryParams,
    ExtensionsManager extensionsManager,
  ) async {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [ExtensionsApi.extensionRootPathPropertyName],
      queryParams: queryParams,
      api: api,
      requestName: ExtensionsApi.apiServeAvailableExtensions,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final logs = <String>[];
    final rootPath = queryParams[ExtensionsApi.extensionRootPathPropertyName];
    final result = <String, Object?>{};
    try {
      await extensionsManager.serveAvailableExtensions(rootPath, logs);
    } on ExtensionParsingException catch (e) {
      // For [ExtensionParsingException]s, we should return a success response
      // with a warning message.
      result[ExtensionsApi.extensionsResultWarningPropertyName] = e.message;
    } catch (e) {
      // For all other exceptions, return an error response.
      return api.serverError('$e', logs);
    }

    final extensions =
        extensionsManager.devtoolsExtensions.map((p) => p.toJson()).toList();
    result[ExtensionsApi.extensionsResultPropertyName] = extensions;
    return ServerApi._encodeResponse(
      ServerApi._wrapWithLogs(result, logs),
      api: api,
    );
  }

  static shelf.Response handleExtensionEnabledState(
    ServerApi api,
    Map<String, String> queryParams,
  ) {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [
        ExtensionsApi.extensionRootPathPropertyName,
        ExtensionsApi.extensionNamePropertyName,
      ],
      queryParams: queryParams,
      api: api,
      requestName: ExtensionsApi.apiExtensionEnabledState,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final rootPath = queryParams[ExtensionsApi.extensionRootPathPropertyName]!;
    final rootUri = Uri.parse(rootPath);
    final extensionName = queryParams[ExtensionsApi.extensionNamePropertyName]!;

    final activate = queryParams[ExtensionsApi.enabledStatePropertyName];
    if (activate != null) {
      final newState = ServerApi._devToolsOptions.setExtensionEnabledState(
        rootUri: rootUri,
        extensionName: extensionName,
        enable: bool.parse(activate),
      );
      return ServerApi._encodeResponse(newState.name, api: api);
    }
    final activationState =
        ServerApi._devToolsOptions.lookupExtensionEnabledState(
      rootUri: rootUri,
      extensionName: extensionName,
    );
    return ServerApi._encodeResponse(activationState.name, api: api);
  }
}

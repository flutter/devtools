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
      [ExtensionsApi.packageRootUriPropertyName],
      queryParams: queryParams,
      api: api,
      requestName: ExtensionsApi.apiServeAvailableExtensions,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final logs = <String>[];
    final rootFileUriString =
        queryParams[ExtensionsApi.packageRootUriPropertyName];
    final result = <String, Object?>{};

    /// Helper to return a success response with all available extensions
    /// detected by [extensionsManager].
    shelf.Response succeedWithAvailableExtensions({String? warning}) {
      final extensions =
          extensionsManager.devtoolsExtensions.map((p) => p.toJson()).toList();
      result[ExtensionsApi.extensionsResultPropertyName] = extensions;
      if (warning != null) {
        result[ExtensionsApi.extensionsResultWarningPropertyName] = warning;
      }
      return ServerApi._encodeResponse(
        ServerApi._wrapWithLogs(result, logs),
        api: api,
      );
    }

    try {
      await extensionsManager.serveAvailableExtensions(
        rootFileUriString,
        logs,
      );
    } on ExtensionParsingException catch (e) {
      // For [ExtensionParsingException]s, we should return a success response
      // with a warning message.
      result[ExtensionsApi.extensionsResultWarningPropertyName] = e.message;
    } catch (e) {
      // If any extensions were successfully detected, return a success response
      // with a warning.
      if (extensionsManager.devtoolsExtensions.isNotEmpty) {
        return succeedWithAvailableExtensions(warning: '$e');
      }
      return api.serverError('$e', logs);
    }

    return succeedWithAvailableExtensions();
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

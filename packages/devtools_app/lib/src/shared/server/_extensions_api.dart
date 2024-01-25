// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

part of 'server.dart';

/// Makes a request to the server to refresh the list of available extensions,
/// serve their assets on the server, and return the list of available
/// extensions here.
Future<List<DevToolsExtensionConfig>> refreshAvailableExtensions(
  Uri appRoot,
) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: ExtensionsApi.apiServeAvailableExtensions,
      queryParameters: {
        ExtensionsApi.extensionRootPathPropertyName: appRoot.toString(),
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      final parsedResult = json.decode(resp!.body) as Map;
      final extensionsAsJson =
          (parsedResult[ExtensionsApi.extensionsResultPropertyName]!
                  as List<Object?>)
              .whereNotNull()
              .cast<Map<String, Object?>>();

      final warningMessage =
          parsedResult[ExtensionsApi.extensionsResultWarningPropertyName];
      if (warningMessage != null) {
        _log.warning(warningMessage);
      }

      return extensionsAsJson
          .map((p) => DevToolsExtensionConfig.parse(p))
          .toList();
    } else {
      logWarning(resp, ExtensionsApi.apiServeAvailableExtensions);
      return [];
    }
  } else if (debugDevToolsExtensions) {
    return debugHandleRefreshAvailableExtensions(appRoot);
  }
  return [];
}

/// Makes a request to the server to look up the enabled state for a
/// DevTools extension, and optionally to set the enabled state (when [enable]
/// is non-null).
///
/// If [enable] is specified, the server will first set the enabled state
/// to the value set forth by [enable] and then return the value that is saved
/// to disk.
Future<ExtensionEnabledState> extensionEnabledState({
  required Uri appRoot,
  required String extensionName,
  bool? enable,
}) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: ExtensionsApi.apiExtensionEnabledState,
      queryParameters: {
        ExtensionsApi.extensionRootPathPropertyName: appRoot.toString(),
        ExtensionsApi.extensionNamePropertyName: extensionName,
        if (enable != null)
          ExtensionsApi.enabledStatePropertyName: enable.toString(),
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      final parsedResult = json.decode(resp!.body);
      return ExtensionEnabledState.from(parsedResult);
    } else {
      logWarning(resp, ExtensionsApi.apiExtensionEnabledState);
    }
  } else if (debugDevToolsExtensions) {
    return debugHandleExtensionEnabledState(
      appRoot: appRoot,
      extensionName: extensionName,
      enable: enable,
    );
  }
  return ExtensionEnabledState.error;
}

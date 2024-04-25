// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

part of 'server.dart';

/// Makes a request to the server to refresh the list of available extensions,
/// serve their assets on the server, and return the list of available
/// extensions here.
Future<List<DevToolsExtensionConfig>> refreshAvailableExtensions(
  Uri? appRoot,
) async {
  _log.fine('refreshAvailableExtensions for app root: ${appRoot.toString()}');
  if (debugDevToolsExtensions) {
    return debugHandleRefreshAvailableExtensions(
      includeRuntime: appRoot != null,
    );
  }
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: ExtensionsApi.apiServeAvailableExtensions,
      queryParameters: {
        ExtensionsApi.packageRootUriPropertyName: appRoot?.toString(),
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      final parsedResult = json.decode(resp!.body) as Map;
      final extensionsAsJson =
          (parsedResult[ExtensionsApi.extensionsResultPropertyName]!
                  as List<Object?>)
              .nonNulls
              .cast<Map<String, Object?>>();

      final logs = (parsedResult['logs'] as List?)?.cast<String>() ?? [];
      for (final log in logs) {
        _log.fine('[from devtools_server] $log');
      }

      final warningMessage =
          parsedResult[ExtensionsApi.extensionsResultWarningPropertyName];
      if (warningMessage != null) {
        _log.warning(warningMessage);
      }

      _log.fine(
        'extensions returned from the server: ${extensionsAsJson.toString()}',
      );

      return extensionsAsJson
          .map((p) => DevToolsExtensionConfig.parse(p))
          .toList();
    } else {
      logWarning(resp, ExtensionsApi.apiServeAvailableExtensions);
      return [];
    }
  }
  return [];
}

/// Makes a request to the server to look up the enabled state for a
/// DevTools extension, and optionally to set the enabled state (when [enable]
/// is non-null).
///
/// [devtoolsOptionsFileUri] is the path to the 'devtools_options.yaml' file
/// where the enabled state for [extensionName] is stored.
///
/// If [enable] is specified, the server will first set the enabled state
/// to the value set forth by [enable] and then return the value that is saved
/// to disk.
Future<ExtensionEnabledState> extensionEnabledState({
  required String devtoolsOptionsFileUri,
  required String extensionName,
  bool? enable,
}) async {
  _log.fine(
    '${enable != null ? 'setting' : 'getting'} extensionEnabledState for '
    '$extensionName in options file ($devtoolsOptionsFileUri)',
  );
  if (debugDevToolsExtensions) {
    return debugHandleExtensionEnabledState(
      extensionName: extensionName,
      enable: enable,
    );
  }
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: ExtensionsApi.apiExtensionEnabledState,
      queryParameters: {
        ExtensionsApi.devtoolsOptionsUriPropertyName: devtoolsOptionsFileUri,
        ExtensionsApi.extensionNamePropertyName: extensionName,
        if (enable != null)
          ExtensionsApi.enabledStatePropertyName: enable.toString(),
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      final parsedResult = json.decode(resp!.body);
      final state = ExtensionEnabledState.from(parsedResult);
      _log.fine('returning state for $extensionName: $state');
      return state;
    } else {
      logWarning(resp, ExtensionsApi.apiExtensionEnabledState);
    }
  }
  return ExtensionEnabledState.error;
}

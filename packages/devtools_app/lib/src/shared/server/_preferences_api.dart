// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

part of 'server.dart';

/// Requests the DevTools preference for the [key].
///
/// This value is stored in the file '~/.flutter-devtools/.devtools'.
Future<String?> getPreferenceValue(String key) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: PreferencesApi.getPreferenceValue,
      queryParameters: {
        PreferencesApi.preferenceKeyProperty: key,
      },
    );
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      return resp!.body;
    } else {
      logWarning(resp, PreferencesApi.getPreferenceValue);
    }
  }
  return null;
}

/// Sets the DevTools preference [value] for the [key].
///
/// This value is stored in the file '~/.flutter-devtools/.devtools'.
Future<void> setPreferenceValue(String key, Object value) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: PreferencesApi.setPreferenceValue,
      queryParameters: {
        PreferencesApi.preferenceKeyProperty: key,
        apiParameterValueKey: value,
      },
    );
    final resp = await request(uri.toString());
    if (resp == null || !resp.statusOk) {
      logWarning(resp, PreferencesApi.setPreferenceValue);
    }
  }
}

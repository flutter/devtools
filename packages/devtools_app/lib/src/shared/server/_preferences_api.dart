// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'server.dart';

/// Requests the DevTools preference for the [key].
///
/// This value is stored in the file '~/.flutter-devtools/.devtools'.
Future<Object?> getPreferenceValue(String key) async {
  if (!isDevToolsServerAvailable) return null;

  final uri = Uri(
    path: PreferencesApi.getPreferenceValue,
    queryParameters: {PreferencesApi.preferenceKeyProperty: key},
  );
  final resp = await request(uri.toString());
  if (resp?.statusOk ?? false) {
    return jsonDecode(resp!.body);
  } else {
    logWarning(resp, PreferencesApi.getPreferenceValue);
    return null;
  }
}

/// Sets the DevTools preference [value] for the [key].
///
/// This value is stored in the file '~/.flutter-devtools/.devtools'.
Future<void> setPreferenceValue(String key, Object value) async {
  if (!isDevToolsServerAvailable) return;

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

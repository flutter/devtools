// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

part of 'server.dart';

// TODO(https://github.com/flutter/devtools/issues/7083): remove these server
// endpoints when the legacy analytics are fully removed.

/// Request DevTools property value 'firstRun' (GA dialog) stored in the file
/// '~/flutter-devtools/.devtools'.
Future<bool> isFirstRun() async {
  bool firstRun = false;
  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetDevToolsFirstRun);
    if (resp?.statusCode == 200) {
      firstRun = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetDevToolsFirstRun);
    }
  }
  return firstRun;
}

/// Request DevTools property value 'enabled' (GA enabled) stored in the file
/// '~/.flutter-devtools/.devtools'.
Future<bool> isAnalyticsEnabled() async {
  bool enabled = false;
  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetDevToolsEnabled);
    if (resp?.statusOk ?? false) {
      enabled = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetDevToolsEnabled);
    }
  }
  return enabled;
}

/// Set the DevTools property 'enabled' (GA enabled) stored in the file
/// '~/.flutter-devtools/.devtools'.
Future<void> setAnalyticsEnabled([bool value = true]) async {
  if (isDevToolsServerAvailable) {
    final resp = await request(
      '$apiSetDevToolsEnabled'
      '?$devToolsEnabledPropertyName=$value',
    );
    if (resp?.statusOk ?? false) {
      assert(json.decode(resp!.body) == value);
    } else {
      logWarning(resp, apiSetDevToolsEnabled);
    }
  }
}

// TODO(terry): Move to an API scheme similar to the VM service extension where
// '/api/devToolsEnabled' returns the value (identical VM service) and
// '/api/devToolsEnabled?value=true' sets the value.

/// Whether GA is enabled in the Flutter store file ~\.flutter.
///
/// A return value of false implies either GA is disabled or the Flutter Tool
/// has never been run.
Future<bool> _isFlutterGAEnabled() async {
  bool enabled = false;

  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetFlutterGAEnabled);
    if (resp?.statusOk ?? false) {
      enabled = json.decode(resp!.body) as bool;
    } else {
      logWarning(resp, apiGetFlutterGAEnabled);
    }
  }

  return enabled;
}

/// Requests the Flutter client id from the Flutter store file ~\.flutter.
///
/// If an empty String is returned, this means that Flutter Tool has never been
/// run.
Future<String> flutterGAClientID() async {
  // Default empty string, Flutter tool never ran.
  String clientId = '';

  if (isDevToolsServerAvailable) {
    // Test if Flutter is enabled (or if Flutter Tool ever ran) if not enabled
    // is false, we don't want to be the first to create a ~/.flutter file.
    if (await _isFlutterGAEnabled()) {
      final resp = await request(apiGetFlutterGAClientId);
      if (resp?.statusOk ?? false) {
        clientId = json.decode(resp!.body);
        if (clientId.isEmpty) {
          _log.warning('$apiGetFlutterGAClientId is empty');
        }
      } else {
        logWarning(resp, apiGetFlutterGAClientId);
      }
    }
  }

  return clientId;
}

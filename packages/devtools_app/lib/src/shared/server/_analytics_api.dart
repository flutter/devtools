// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

part of 'server.dart';

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
///
/// Returns whether the set call was successful.
Future<bool> setAnalyticsEnabled([bool value = true]) async {
  if (isDevToolsServerAvailable) {
    final resp = await request(
      '$apiSetDevToolsEnabled'
      '?$devToolsEnabledPropertyName=$value',
    );
    if (resp?.statusOk ?? false) {
      assert(json.decode(resp!.body) == value);
      return true;
    } else {
      logWarning(resp, apiSetDevToolsEnabled, resp?.body);
    }
  }
  return false;
}

/// Fetch the consent message for package:unified_analytics.
Future<String> fetchAnalyticsConsentMessage() async {
  String? consentMessage = '';
  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetConsentMessage);
    if (resp?.statusOk ?? false) {
      consentMessage = resp!.body;
    }
  }

  return consentMessage;
}

/// Confirm with package:unified_analytics that the consent message
/// has been shown to the user.
Future<void> confirmConsentMessageShown() async {
  if (isDevToolsServerAvailable) {
    await request(apiAnalyticsConsentMessageShown);
  }
}

// TODO(terry): Move to an API scheme similar to the VM service extension where
// '/api/devToolsEnabled' returns the value (identical VM service) and
// '/api/devToolsEnabled?value=true' sets the value.

/// Request Flutter tool stored property value enabled (GA enabled) stored in
/// the file '~\.flutter'.
///
/// Return bool.
/// Return value of false implies either GA is disabled or the Flutter Tool has
/// never been run (null returned from the server).
Future<bool> _isFlutterGAEnabled() async {
  bool enabled = false;

  if (isDevToolsServerAvailable) {
    final resp = await request(apiGetFlutterGAEnabled);
    if (resp?.statusOk ?? false) {
      // A return value of 'null' implies Flutter tool has never been run so
      // return false for Flutter GA enabled.
      final responseValue = json.decode(resp!.body);
      enabled = responseValue ?? false;
    } else {
      logWarning(resp, apiGetFlutterGAEnabled);
    }
  }

  return enabled;
}

/// Request Flutter tool stored property value clientID (GA enabled) stored in
/// the file '~\.flutter'.
///
/// Return as a String, empty string implies Flutter Tool has never been run.
Future<String> flutterGAClientID() async {
  // Default empty string, Flutter tool never run.
  String clientId = '';

  if (isDevToolsServerAvailable) {
    // Test if Flutter is enabled (or if Flutter Tool ever ran) if not enabled
    // is false, we don't want to be the first to create a ~/.flutter file.
    if (await _isFlutterGAEnabled()) {
      final resp = await request(apiGetFlutterGAClientId);
      if (resp?.statusOk ?? false) {
        clientId = json.decode(resp!.body);
        if (clientId.isEmpty) {
          // Requested value of 'null' (Flutter tool never ran). Server request
          // apiGetFlutterGAClientId should not happen because the
          // isFlutterGAEnabled test should have been false.
          _log.warning('$apiGetFlutterGAClientId is empty');
        }
      } else {
        logWarning(resp, apiGetFlutterGAClientId);
      }
    }
  }

  return clientId;
}

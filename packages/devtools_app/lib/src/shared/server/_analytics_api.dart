// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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

/// Requests the Flutter client id from the Flutter store file ~\.flutter.
///
/// If an empty String is returned, this means that Flutter Tool has never been
/// run.
Future<String> flutterGAClientID() async {
  // Default empty string, Flutter tool never ran.
  String clientId = '';

  if (isDevToolsServerAvailable) {
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

  return clientId;
}

// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'server.dart';

/// Requests the DevTools version for which we last showed release notes.
///
/// This value is stored in the file '~/.flutter-devtools/.devtools'.
Future<String> getLastShownReleaseNotesVersion() async {
  String version = '';
  if (isDevToolsServerAvailable) {
    final resp = await request(ReleaseNotesApi.getLastReleaseNotesVersion);
    if (resp?.statusOk ?? false) {
      version = json.decode(resp!.body);
    } else {
      logWarning(resp, ReleaseNotesApi.getLastReleaseNotesVersion);
    }
  }
  return version;
}

/// Sets the DevTools version for which we last showed release notes.
///
/// This value is stored in the file '~/.flutter-devtools/.devtools'.
Future<void> setLastShownReleaseNotesVersion(String version) async {
  if (isDevToolsServerAvailable) {
    final resp = await request(
      '${ReleaseNotesApi.setLastReleaseNotesVersion}'
      '?$apiParameterValueKey=$version',
    );
    if (resp == null || !resp.statusOk) {
      logWarning(resp, ReleaseNotesApi.setLastReleaseNotesVersion);
    }
  }
}

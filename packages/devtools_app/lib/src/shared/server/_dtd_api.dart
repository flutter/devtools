// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

part of 'server.dart';

/// Asks the Devtools Server to return a Dart Tooling Daemon uri if it has one.
Future<Uri?> getDtdUri() async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(path: DtdApi.apiGetDtdUri);
    final resp = await request(uri.toString());
    if (resp?.statusOk ?? false) {
      final parsedResult = json.decode(resp!.body) as Map;
      final uriString = parsedResult[DtdApi.uriPropertyName] as String?;
      return uriString != null ?  Uri.parse(uriString) : null;
    }
  }
  return null;
}

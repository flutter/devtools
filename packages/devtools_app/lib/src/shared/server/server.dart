// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

import '../development_helpers.dart';
import '../primitives/utils.dart';

part '_analytics_api.dart';
part '_app_size_api.dart';
part '_deep_links_api.dart';
part '_extensions_api.dart';
part '_release_notes_api.dart';
part '_survey_api.dart';
part '_dtd_api.dart';

final _log = Logger('devtools_server_client');

// The DevTools server is only available in release mode right now.
// TODO(kenz): design a way to run the DevTools server and DevTools app together
// in debug mode.
bool get isDevToolsServerAvailable => kReleaseMode;

/// Helper to catch any server request which could fail.
///
/// Returns HttpRequest or null (if server failure).
Future<Response?> request(String url) async {
  Response? response;

  try {
    _log.fine('requesting $url');
    response = await post(Uri.parse(url));
  } catch (_) {}

  return response;
}

Future<DevToolsJsonFile?> requestFile({
  required String api,
  required String fileKey,
  required String filePath,
}) async {
  if (isDevToolsServerAvailable) {
    final url = Uri(path: api, queryParameters: {fileKey: filePath});
    final resp = await request(url.toString());
    if (resp?.statusOk ?? false) {
      return _devToolsJsonFileFromResponse(resp!, filePath);
    } else {
      logWarning(resp, api);
    }
  }
  return null;
}

Future<void> notifyForVmServiceConnection({
  required String vmServiceUri,
  required bool connected,
}) async {
  if (isDevToolsServerAvailable) {
    final uri = Uri(
      path: apiNotifyForVmServiceConnection,
      queryParameters: {
        apiParameterValueKey: vmServiceUri,
        apiParameterVmServiceConnected: connected.toString(),
      },
    );
    final resp = await request(uri.toString());
    final statusOk = resp?.statusOk ?? false;
    if (!statusOk) {
      logWarning(resp, apiNotifyForVmServiceConnection);
    }
  }
}

DevToolsJsonFile _devToolsJsonFileFromResponse(
  Response resp,
  String filePath,
) {
  final data = json.decode(resp.body) as Map;
  final lastModified = data['lastModifiedTime'];
  final lastModifiedTime =
      lastModified != null ? DateTime.parse(lastModified) : DateTime.now();
  return DevToolsJsonFile(
    name: filePath,
    lastModifiedTime: lastModifiedTime,
    data: data,
  );
}

void logWarning(Response? response, String apiType) {
  final respText = response?.body;
  _log.warning(
    'HttpRequest $apiType failed status = ${response?.statusCode}'
    '${respText.isNullOrEmpty ? '' : ', responseText = $respText'}',
  );
}

extension ResponseExtension on Response {
  bool get statusOk => statusCode == 200;
  bool get statusForbidden => statusCode == 403;
  bool get statusError => statusCode == 500;
}

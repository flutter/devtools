// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of 'server_api.dart';

abstract class _DtdApiHandler {
  static shelf.Response handleGetDtdUri(
    ServerApi api,
    DTDConnectionInfo? dtd,
  ) {
    return ServerApi._encodeResponse(
      {DtdApi.uriPropertyName: dtd?.uri},
      api: api,
    );
  }

  static Future<shelf.Response> handleSetDtdWorkspaceRoots(
    ServerApi api,
    Map<String, String> queryParams,
    DTDConnectionInfo? dtd,
  ) async {
    final uri = dtd?.uri;
    final secret = dtd?.secret;
    if (uri == null) {
      return api.serverError(
        'Cannot set workspace roots because DTD is not available.',
      );
    }
    if (secret == null) {
      return api.forbidden(
        'Cannot set workspace roots because DevTools server is not the trusted '
        'client for DTD.',
      );
    }

    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [DtdApi.workspaceRootsPropertyName],
      queryParams: queryParams,
      api: api,
      requestName: DtdApi.apiSetDtdWorkspaceRoots,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final roots = DtdApi.decodeWorkspaceRoots(
      queryParams[DtdApi.workspaceRootsPropertyName]!,
    ).map((r) => Uri.parse(r)).toList();

    DTDConnection? dtdConnection;
    try {
      dtdConnection = await DartToolingDaemon.connect(Uri.parse(uri));
      await dtdConnection.setIDEWorkspaceRoots(secret, roots);
      return api.success();
    } catch (e) {
      return api.serverError('$e');
    } finally {
      await dtdConnection?.close();
    }
  }
}

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of 'server_api.dart';

abstract class _DtdApiHandler {
  static shelf.Response handleGetDtdUri(
    ServerApi api,
    ({String? uri, String? secret})? dtd,
  ) {
    return ServerApi._encodeResponse(
      {DtdApi.uriPropertyName: dtd?.uri},
      api: api,
    );
  }

  static Future<shelf.Response> handleSetDtdWorkspaceRoots(
    ServerApi api,
    Map<String, String> queryParams,
    ({String? uri, String? secret})? dtd,
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

    final roots = (queryParams[DtdApi.apiSetDtdWorkspaceRoots]! as List<String>)
        .map((r) => Uri.file(r))
        .toList();
    try {
      final dtdConnection = await DartToolingDaemon.connect(Uri.parse(uri));
      await dtdConnection.setIDEWorkspaceRoots(secret, roots);

      final newRoots = await dtdConnection.getIDEWorkspaceRoots();
      final newRootsAsStrings =
          newRoots.ideWorkspaceRoots.map((uri) => uri.toString()).toList();
      print('newRoots: $newRootsAsStrings');
      return api.success();
    } catch (e) {
      return api.serverError('$e');
    }
  }
}

// /// A data object representing a Dart Tooling Daemon instance.
// class DtdMetadata {
//   const DtdMetadata({this.uri, this.secret});

//   /// The URI for the Dart Tooling Daemon that DevTools is connected to.
//   final String? uri;

//   /// The secret for the Dart Tooling Daemon's trusted client when DTD was
//   /// started by the DevTools server.
//   ///
//   /// This will be null if DTD was started by another client (e.g. the IDE).
//   final String? secret;
// }

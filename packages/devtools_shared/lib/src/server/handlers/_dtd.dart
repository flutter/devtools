// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../server_api.dart';

/// A namespace for Dart Tooling Daemon (DTD) server request handlers.
extension _DtdApiHandler on Never {
  static shelf.Response handleGetDtdUri(
    ServerApi api,
    DtdInfo? dtd,
  ) {
    return ServerApi._encodeResponse(
      {
        // Always provide the exposed URI to callers of the web API.
        DtdApi.uriPropertyName: dtd?.exposedUri.toString(),
      },
      api: api,
    );
  }
}

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _DtdApiHandler {
  static shelf.Response handleGetDtdUri(
    ServerApi api,
    DTDInfo? dtd,
  ) {
    return ServerApi._encodeResponse(
      {
        // Always provide the exposed URI to callers of the web API.
        // TODO(dantup): Should we add properties for both URIs and deprecate
        //  "uri"? Would anyone on the backend ever call this API?
        DtdApi.uriPropertyName: dtd?.exposedUri,
      },
      api: api,
    );
  }
}

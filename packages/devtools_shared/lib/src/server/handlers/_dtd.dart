// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _DtdApiHandler {
  static shelf.Response handleGetDtdUri(
    ServerApi api,
    String? dtdUri,
  ) {
    return ServerApi._encodeResponse(
      {DtdApi.uriPropertyName: dtdUri},
      api: api,
    );
  }
}

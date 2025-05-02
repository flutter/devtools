// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../server_api.dart';

/// A namespace for local storage request handlers.
extension _StorageHandler on Never {
  static shelf.Response handleGetStorageValue<T>(
    ServerApi api,
    DevToolsUsage devToolsStore, {
    required String key,
    T? defaultValue,
  }) {
    final T? value = (devToolsStore.properties[key] as T?) ?? defaultValue;
    return ServerApi._encodeResponse(value, api: api);
  }

  static shelf.Response handleSetStorageValue<T>(
    ServerApi api,
    DevToolsUsage devToolsStore, {
    required String key,
    required T value,
  }) {
    devToolsStore.properties[key] = value;
    return ServerApi._encodeResponse(devToolsStore.properties[key], api: api);
  }
}

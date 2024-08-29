// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _StorageHandler {
  static shelf.Response handleGetStorageValue<T>(
    ServerApi api,
    DevToolsUsage devToolsStore, {
    required String key,
    required T defaultValue,
  }) {
    final T value = (devToolsStore.properties[key] as T?) ?? defaultValue;
    return ServerApi._encodeResponse(
      value,
      api: api,
    );
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

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _ReleaseNotesHandler {
  static shelf.Response getLastReleaseNotesVersion(
    ServerApi api,
    DevToolsUsage devToolsStore,
  ) {
    return _StorageHandler.handleGetStorageValue<String>(
      api,
      devToolsStore,
      key: DevToolsStoreKeys.lastReleaseNotesVersion.name,
      defaultValue: '',
    );
  }

  static shelf.Response setLastReleaseNotesVersion(
    ServerApi api,
    Map<String, String> queryParams,
    DevToolsUsage devToolsStore,
  ) {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [apiParameterValueKey],
      queryParams: queryParams,
      api: api,
      requestName: ReleaseNotesApi.setLastReleaseNotesVersion,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    return _StorageHandler.handleSetStorageValue<String>(
      api,
      devToolsStore,
      key: DevToolsStoreKeys.lastReleaseNotesVersion.name,
      value: queryParams[apiParameterValueKey]!,
    );
  }
}

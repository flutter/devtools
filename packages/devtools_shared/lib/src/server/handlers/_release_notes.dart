// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../server_api.dart';

/// A namespace for release notes server request handlers.
extension _ReleaseNotesHandler on Never {
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

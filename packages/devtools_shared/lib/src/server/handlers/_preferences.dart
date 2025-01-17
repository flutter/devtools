// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _PreferencesApiHandler {
  static shelf.Response getPreferenceValue<T>(
    ServerApi api,
    Map<String, String> queryParams,
    DevToolsUsage devToolsStore,
  ) {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [PreferencesApi.preferenceKeyProperty],
      queryParams: queryParams,
      api: api,
      requestName: PreferencesApi.getPreferenceValue,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    return _StorageHandler.handleGetStorageValue<T>(
      api,
      devToolsStore,
      key: queryParams[PreferencesApi.preferenceKeyProperty]!,
    );
  }

  static shelf.Response setPreferenceValue<T>(
    ServerApi api,
    Map<String, String> queryParams,
    DevToolsUsage devToolsStore,
  ) {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [PreferencesApi.preferenceKeyProperty, apiParameterValueKey],
      queryParams: queryParams,
      api: api,
      requestName: PreferencesApi.setPreferenceValue,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    return _StorageHandler.handleSetStorageValue<T>(
      api,
      devToolsStore,
      key: queryParams[PreferencesApi.preferenceKeyProperty]!,
      value: queryParams[apiParameterValueKey]! as T,
    );
  }
}

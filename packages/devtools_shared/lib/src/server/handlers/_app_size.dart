// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _AppSizeHandler {
  static shelf.Response getBaseAppSizeFile(
    ServerApi api,
    Map<String, String> queryParams,
  ) {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [AppSizeApi.baseAppSizeFilePropertyName],
      queryParams: queryParams,
      api: api,
      requestName: AppSizeApi.getBaseAppSizeFile,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final filePath = queryParams[AppSizeApi.baseAppSizeFilePropertyName]!;
    final fileJson = LocalFileSystem.devToolsFileAsJson(filePath);
    if (fileJson == null) {
      return api.badRequest('No JSON file available at $filePath.');
    }
    return api.success(fileJson);
  }

  static shelf.Response getTestAppSizeFile(
    ServerApi api,
    Map<String, String> queryParams,
  ) {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [AppSizeApi.testAppSizeFilePropertyName],
      queryParams: queryParams,
      api: api,
      requestName: AppSizeApi.getTestAppSizeFile,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final filePath = queryParams[AppSizeApi.testAppSizeFilePropertyName]!;
    final fileJson = LocalFileSystem.devToolsFileAsJson(filePath);
    if (fileJson == null) {
      return api.badRequest('No JSON file available at $filePath.');
    }
    return api.success(fileJson);
  }
}

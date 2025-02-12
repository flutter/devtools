// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'server.dart';

Future<DevToolsJsonFile?> requestBaseAppSizeFile(String path) {
  return requestFile(
    api: AppSizeApi.getBaseAppSizeFile,
    fileKey: AppSizeApi.baseAppSizeFilePropertyName,
    filePath: path,
  );
}

Future<DevToolsJsonFile?> requestTestAppSizeFile(String path) {
  return requestFile(
    api: AppSizeApi.getTestAppSizeFile,
    fileKey: AppSizeApi.testAppSizeFilePropertyName,
    filePath: path,
  );
}

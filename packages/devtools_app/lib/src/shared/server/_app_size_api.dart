// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

part of 'server.dart';

Future<DevToolsJsonFile?> requestBaseAppSizeFile(String path) {
  return requestFile(
    api: apiGetBaseAppSizeFile,
    fileKey: baseAppSizeFilePropertyName,
    filePath: path,
  );
}

Future<DevToolsJsonFile?> requestTestAppSizeFile(String path) {
  return requestFile(
    api: apiGetTestAppSizeFile,
    fileKey: testAppSizeFilePropertyName,
    filePath: path,
  );
}

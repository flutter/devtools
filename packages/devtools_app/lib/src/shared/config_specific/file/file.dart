// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '_file_stub.dart'
    if (dart.library.js_interop) '_file_web.dart'
    if (dart.library.io) '_file_desktop.dart';

abstract class FileIO {
  factory FileIO() {
    return createFileSystem();
  }

  String exportDirectoryName({bool isMemory = false});

  /// Create file in a directory (default Downloads).
  // TODO(terry): Better directory for Flutter Desktop when API available.
  // TODO(terry): Flutter Web/HTML port code to create file in Download directory.
  void writeStringToFile(
    String filename,
    String contents, {
    bool isMemory = false,
  });

  /// Returns content of filename or null if file is unknown or content empty.
  String? readStringFromFile(String filename, {bool isMemory = false});

  /// List of files (basename only).
  List<String> list({required String prefix, bool isMemory = false});

  /// Delete exported files created for testing only.
  bool deleteFile(String path, {bool isMemory = false});
}

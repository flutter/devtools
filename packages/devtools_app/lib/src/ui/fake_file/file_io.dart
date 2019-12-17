// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

abstract class FileIO {
  /// Create file in a directory (default Desktop in \tmp).
  // TODO(terry): Better directory for Flutter Desktop when API available.
  // TODO(terry): Flutter Web/HTML port code to create file in Download directory.
  void writeStringToFile(String filename, String contents);

  /// Returns content of filename or null if file is unknown or content empty.
  String readStringFromFile(String filename);

  /// List of files (basename only).
  List<String> list();

  /// Delete exported files created for testing only.
  bool deleteFile(String path);
}

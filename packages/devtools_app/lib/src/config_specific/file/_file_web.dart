// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'file.dart';

FileSystemWeb createFileSystem() {
  return FileSystemWeb();
}

/// Abstracted file system access for Flutter Web.
class FileSystemWeb implements FileIO {
  // TODO(terry): Implement Web based file IO.

  /// Key is filename and value is content of the file.
  final Map<String, String> _files = {};

  /// In memory file system.

  @override
  String exportDirectoryName({bool isMemory = false}) => 'LocalStorage';

  @override
  void writeStringToFile(String filename, String contents,
      {bool isMemory = false}) {
    _files.putIfAbsent(filename, () => contents);
  }

  @override
  String? readStringFromFile(String filename, {bool isMemory = false}) =>
      _files.containsKey(filename) ? _files[filename]! : null;

  @override
  List<String> list({required String prefix, bool isMemory = false}) =>
      _files.keys.toList();

  @override
  bool deleteFile(String filename, {bool isMemory = false}) =>
      _files.remove(filename) != null;
}

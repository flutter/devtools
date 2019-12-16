// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'file_io.dart';

/// Abstracted memory file system access for Flutter Web.
class MemoryFiles implements FileIO {
  // TODO(terry): Implement Web based file IO.

  final Map<String, String> _files = {};

  @override
  void writeStringToFile(String filename, String contents) {
    _files.putIfAbsent(filename, () => contents);
  }

  @override
  String readStringFromFile(String filename) =>
      _files.containsKey(filename) ? _files[filename] : null;

  @override
  List<String> list({String prefix}) => _files.keys.toList();

  @override
  bool deleteFile(String filename) => _files.remove(filename) != null;
}

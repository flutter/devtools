// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


/// Abstracted memory and local file system access for Flutter Desktop.

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as _path;

import 'file_io.dart';

class MemoryFiles implements FileIO {
  final _fs = const LocalFileSystem();

  @override
  void writeStringToFile(String filename, String contents) {
    // TODO(terry): Consider path_provider's getTemporaryDirectory
    //              or getApplicationDocumentsDirectory when
    //              available in Flutter Web/Desktop.
    final memoryLogFile = _fs.systemTempDirectory.childFile(filename);
    memoryLogFile.writeAsStringSync(contents, flush: true);
  }

  @override
  String readStringFromFile(String filename) {
    final previousCurrentDirectory = _fs.currentDirectory;

    // TODO(terry): Use path_provider when available?
    _fs.currentDirectory = _fs.systemTempDirectory;

    final memoryLogFile = _fs.currentDirectory.childFile(filename);

    final jsonPayload = memoryLogFile.readAsStringSync();

    _fs.currentDirectory = previousCurrentDirectory;

    return jsonPayload;
  }

  @override
  List<String> list({String prefix}) {
    final List<String> memoryLogs = [];

    final previousCurrentDirectory = _fs.currentDirectory;

    // TODO(terry): Use path_provider when available?
    _fs.currentDirectory = _fs.systemTempDirectory;

    final allFiles = _fs.currentDirectory.listSync();

    for (FileSystemEntity entry in allFiles) {
      final basename = _path.basename(entry.path);
      if (_fs.isFileSync(entry.path) && basename.startsWith(prefix)) {
        memoryLogs.add(basename);
      }
    }

    // Sort by newest file top-most (DateTime is in the filename).
    memoryLogs.sort((a, b) => b.compareTo(a));

    _fs.currentDirectory = previousCurrentDirectory;

    return memoryLogs;
  }

  @override
  bool deleteFile(String path) {
    final previousCurrentDirectory = _fs.currentDirectory;

    // TODO(terry): Use path_provider when available?
    _fs.currentDirectory = _fs.systemTempDirectory;

    if (!_fs.isFileSync(path)) return false;

    _fs.file(path).deleteSync();

    _fs.currentDirectory = previousCurrentDirectory;

    return true;
  }
}

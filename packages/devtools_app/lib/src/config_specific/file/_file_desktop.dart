// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as _path;

import '../logger/logger.dart';

import 'file.dart';

FileSystemDesktop createFileSystem() {
  return FileSystemDesktop();
}

/// Abstracted local file system access for Flutter Desktop.
class FileSystemDesktop implements FileIO {
  final _fs = const LocalFileSystem();

  @override
  String exportDirectoryName({bool isMemory = false}) =>
      _exportDirectory(isMemory: isMemory).path;

  /// Flutter Desktop MacOS systemTempDirectory is in Downloads
  /// for memory files location is $TMPDIR.
  /// Flutter Desktop Linux systemTempDirectory is \tmp
  // TODO(terry): isMemory is temporary workaround for listSync hanging issue when
  //              listing files in Downloads (probably a security issue). Re-work
  //              how import works using drag/drop.
  Directory _exportDirectory({bool isMemory = false}) {
    // TODO(terry): macOS returns /var/folders/xxx/yyy for temporary. Where
    // xxx & yyy are generated names hard to locate the json file.
    if (!isMemory && _fs.systemTempDirectory.dirname.startsWith('/var/')) {
      // TODO(terry): For now export the file to the user's Downloads.
      final dirPath = _fs.currentDirectory.dirname.split('/');
      // check length prevent Memory tab crash in macos
      if (dirPath.length > 2) {
        final downloadsPath = '/${dirPath[1]}/${dirPath[2]}/Downloads';
        return _fs.directory(downloadsPath);
      }
    }
    return _fs.systemTempDirectory;
  }

  @override
  void writeStringToFile(String filename, String contents,
      {bool isMemory = false}) {
    final logFile = _exportDirectory(isMemory: isMemory).childFile(filename);
    logFile.writeAsStringSync(contents, flush: true);
  }

  @override
  String readStringFromFile(String filename, {bool isMemory = false}) {
    final previousCurrentDirectory = _fs.currentDirectory;

    // TODO(terry): Use path_provider when available?
    _fs.currentDirectory = _exportDirectory(isMemory: isMemory);

    final logFile = _fs.currentDirectory.childFile(filename);

    final jsonPayload = logFile.readAsStringSync();

    _fs.currentDirectory = previousCurrentDirectory;

    return jsonPayload;
  }

  @override
  List<String> list({required String prefix, bool isMemory = false}) {
    final List<String> logs = [];

    try {
      // TODO(terry): Use path_provider when available?
      final directory = _exportDirectory(isMemory: isMemory);

      if (!directory.existsSync()) {
        return logs;
      }

      final allFiles = directory.listSync(followLinks: false);
      for (FileSystemEntity entry in allFiles) {
        final basename = _path.basename(entry.path);
        if (_fs.isFileSync(entry.path) && basename.startsWith(prefix)) {
          logs.add(basename);
        }
      }

      // Sort by newest file top-most (DateTime is in the filename).
      logs.sort((a, b) => b.compareTo(a));
    } on FileSystemException catch (e) {
      // TODO(jacobr): prompt the user to grant permission to access the
      // directory if Flutter ever provides that option or consider using an
      // alternate directory. This error should generally only occur on MacOS
      // desktop Catalina and later  where access to the Downloads folder
      // is not granted by default.
      log(e.toString());
    }

    return logs;
  }

  @override
  bool deleteFile(String path, {bool isMemory = false}) {
    final previousCurrentDirectory = _fs.currentDirectory;

    // TODO(terry): Use path_provider when available?
    _fs.currentDirectory = _exportDirectory(isMemory: isMemory);

    if (!_fs.isFileSync(path)) return false;

    _fs.file(path).deleteSync();

    _fs.currentDirectory = previousCurrentDirectory;

    return true;
  }
}

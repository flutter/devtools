// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/local.dart';

/// Abstracted local file system access for Flutter Desktop.
class FileSystemDesktop {
  final _fs = const LocalFileSystem();

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

  /// Create file in a directory (default Downloads).
  void writeContentsToFile<T>(
    String filename,
    T contents, {
    bool isMemory = false,
  }) {
    final file = _exportDirectory(isMemory: isMemory).childFile(filename);
    if (contents is String) {
      file.writeAsStringSync(contents, flush: true);
    } else if (contents is Uint8List) {
      file.writeAsBytesSync(contents, flush: true);
    } else {
      throw StateError('Unsupported content type: $T');
    }
  }
}

// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:devtools_shared/src/server/file_system.dart' hide fileSystem;
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  group('LocalFileSystem.devToolsFileFromPath', () {
    late MemoryFileSystem fs;

    setUp(() {
      fs = MemoryFileSystem();
      fs
          .directory(FileSystemExtension.devToolsDir)
          .parent
          .createSync(recursive: true);
    });

    group('path validation', () {
      // These inputs must be rejected before any filesystem access so that reads
      // stay confined to the ~/.flutter-devtools/ directory.

      test('rejects absolute paths', () {
        // path.join() discards the base directory when its second argument is
        // absolute, so an absolute path would otherwise escape the DevTools
        // directory and read an arbitrary file on disk.
        expect(fs.devToolsFileFromPath('/etc/passwd'), isNull);
        expect(fs.devToolsFileFromPath('/absolute/path/to/file.json'), isNull);
      });

      test('rejects paths containing ".."', () {
        expect(fs.devToolsFileFromPath('..'), isNull);
        expect(fs.devToolsFileFromPath('../../../etc/passwd'), isNull);
        expect(fs.devToolsFileFromPath('subdir/../../escape.json'), isNull);
      });
    });

    test('returns file when path is valid and file exists', () {
      final devToolsDir = FileSystemExtension.devToolsDir;
      final testFile = fs.file('$devToolsDir/sub/file.json')
        ..createSync(recursive: true);

      final file = fs.devToolsFileFromPath('sub/file.json')!;
      expect(file.path, testFile.path);
    });

    test('returns null when path is valid but file does not exist', () {
      final file = fs.devToolsFileFromPath('sub/non_existent.json');
      expect(file, isNull);
    });
  });

  group('LocalFileSystem.devToolsFileAsJson', () {
    late MemoryFileSystem fs;

    setUp(() {
      fs = MemoryFileSystem();
      fs
          .directory(FileSystemExtension.devToolsDir)
          .parent
          .createSync(recursive: true);
    });

    test('returns null if file does not exist', () {
      expect(fs.devToolsFileAsJson('test.json'), isNull);
    });

    test('returns null if file is not json', () {
      final devToolsDir = FileSystemExtension.devToolsDir;
      fs.file('$devToolsDir/test.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync('hello');
      expect(fs.devToolsFileAsJson('test.txt'), isNull);
    });

    test('returns json content with lastModifiedTime', () {
      final devToolsDir = FileSystemExtension.devToolsDir;
      final file = fs.file('$devToolsDir/test.json')
        ..createSync(recursive: true);
      file.writeAsStringSync('{"key": "value"}');

      final jsonStr = fs.devToolsFileAsJson('test.json')!;
      final json = jsonDecode(jsonStr) as Map;
      expect(json['key'], 'value');
      expect(json['lastModifiedTime'], file.lastModifiedSync().toString());
    });
  });
}

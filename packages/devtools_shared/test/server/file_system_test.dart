// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_shared/src/server/file_system.dart';
import 'package:test/test.dart';

void main() {
  group('LocalFileSystem.devToolsFileFromPath path validation', () {
    // These inputs must be rejected before any filesystem access so that reads
    // stay confined to the ~/.flutter-devtools/ directory.

    test('rejects absolute paths', () {
      // path.join() discards the base directory when its second argument is
      // absolute, so an absolute path would otherwise escape the DevTools
      // directory and read an arbitrary file on disk.
      expect(LocalFileSystem.devToolsFileFromPath('/etc/passwd'), isNull);
      expect(
        LocalFileSystem.devToolsFileFromPath('/absolute/path/to/file.json'),
        isNull,
      );
    });

    test('rejects paths containing ".."', () {
      expect(LocalFileSystem.devToolsFileFromPath('..'), isNull);
      expect(
        LocalFileSystem.devToolsFileFromPath('../../../etc/passwd'),
        isNull,
      );
      expect(
        LocalFileSystem.devToolsFileFromPath('subdir/../../escape.json'),
        isNull,
      );
    });
  });
}

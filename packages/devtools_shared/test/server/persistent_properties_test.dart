// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:devtools_shared/src/server/file_system.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  group('IOPersistentProperties', () {
    late MemoryFileSystem fs;
    late Directory tempDir;
    late IOPersistentProperties properties;
    const storeName = 'test_store';

    setUp(() {
      fs = MemoryFileSystem();
      tempDir = fs.systemTempDirectory.createTempSync(
        'persistent_properties_test',
      );
      properties = IOPersistentProperties(
        storeName,
        documentDirPath: tempDir.path,
        fs: fs,
      );
    });

    test('remove persists changes to disk', () {
      properties['key1'] = 'value1';
      properties['key2'] = 'value2';

      final file = fs.file('${tempDir.path}/$storeName');
      expect(file.existsSync(), isTrue);

      var content = file.readAsStringSync();
      var json = (jsonDecode(content) as Map).cast<String, Object>();
      expect(json['key1'], 'value1');
      expect(json['key2'], 'value2');

      properties.remove('key1');

      content = file.readAsStringSync();
      json = (jsonDecode(content) as Map).cast<String, Object>();
      expect(json.containsKey('key1'), isFalse);
      expect(json['key2'], 'value2');
    });
  });
}

// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:io';

import 'package:devtools_shared/devtools_extensions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory from;
  late Directory to;

  tearDown(() {
    // Delete [to] first so that we do not hit a file system exception when [to]
    // is a subdirectory of [from].
    to.deleteSync(recursive: true);
    from.deleteSync(recursive: true);
  });

  test('copyPath', () async {
    from = _createFromDir();
    to = _createToDir();

    await copyPath(from.path, to.path);
    const expected =
        "[File: 'tmp/foo.txt', Directory: 'tmp/bar', File: 'tmp/bar/baz.txt']";
    final fromContents = from.listSync(recursive: true);
    final toContents = to.listSync(recursive: true);
    expect(fromContents.toString(), expected);
    expect(toContents.toString(), expected.replaceAll('tmp', 'tmp2'));
  });

  test('copy path throws for infinite operation', () async {
    from = _createFromDir();
    to = Directory(p.join(from.path, 'bar'));
    expect(to.existsSync(), isTrue);
    await expectLater(copyPath(from.path, to.path), throwsArgumentError);
  });
}

Directory _createFromDir() {
  final from = Directory('tmp')..createSync();
  File.fromUri(Uri.parse(p.join(from.path, 'foo.txt')))..createSync();
  final dir = Directory(p.join(from.path, 'bar'))..createSync();
  File.fromUri(Uri.parse(p.join(dir.path, 'baz.txt')))..createSync();
  final contents = from.listSync(recursive: true);
  expect(
    contents.toString(),
    "[File: 'tmp/foo.txt', Directory: 'tmp/bar', File: 'tmp/bar/baz.txt']",
  );
  return from;
}

Directory _createToDir() {
  final to = Directory('tmp2')..createSync();
  final contents = to.listSync(recursive: true);
  expect(contents.toString(), '[]');
  return to;
}

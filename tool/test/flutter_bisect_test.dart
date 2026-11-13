// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:devtools_tool/commands/flutter_bisect_helper.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('findFirstBadCommit', () {
    test('finds first bad in the middle', () {
      const commits = ['c1', 'c2', 'c3', 'c4', 'c5'];
      final firstBad = {
        'c1': false,
        'c2': false,
        'c3': true,
        'c4': true,
        'c5': true,
      };

      expect(findFirstBadCommit(commits, isBad: (c) => firstBad[c]!), 'c3');
    });

    test('finds first commit when it is bad', () {
      const commits = ['c1', 'c2', 'c3'];
      expect(findFirstBadCommit(commits, isBad: (_) => true), 'c1');
    });

    test('finds last commit when only last is bad', () {
      const commits = ['c1', 'c2', 'c3'];
      expect(findFirstBadCommit(commits, isBad: (c) => c == 'c3'), 'c3');
    });

    test('works with a single commit', () {
      expect(findFirstBadCommit(['only'], isBad: (_) => true), 'only');
    });

    test('throws on empty list', () {
      expect(
        () => findFirstBadCommit([], isBad: (_) => true),
        throwsArgumentError,
      );
    });
  });

  group('findFirstBadCommitAsync', () {
    test('matches sync helper', () async {
      const commits = ['a', 'b', 'c', 'd'];
      final result = await findFirstBadCommitAsync(
        commits,
        isBad: (c) async => c == 'c' || c == 'd',
      );
      expect(result, 'c');
    });
  });

  group('findPackageDirectory', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_bisect_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('finds nearest pubspec.yaml above the test file', () {
      final packageDir = Directory(path.join(tempDir.path, 'pkg'))
        ..createSync();
      File(
        path.join(packageDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: example\n');
      final testDir = Directory(path.join(packageDir.path, 'test'))
        ..createSync();
      final testFile = File(path.join(testDir.path, 'foo_test.dart'))
        ..writeAsStringSync('');

      expect(findPackageDirectory(testFile.path), packageDir.path);
    });

    test('returns null when no pubspec.yaml exists', () {
      final testFile = File(path.join(tempDir.path, 'orphan_test.dart'))
        ..writeAsStringSync('');
      expect(findPackageDirectory(testFile.path), isNull);
    });
  });
}

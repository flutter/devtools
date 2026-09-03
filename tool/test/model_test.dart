// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:devtools_tool/devtools_command_runner.dart';
import 'package:devtools_tool/model.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('DevToolsCommandRunner', () {
    test('parses --flutter-from-path flag', () {
      final runner = DevToolsCommandRunner();
      final results = runner.argParser.parse(['-p']);
      expect(results['flutter-from-path'], isTrue);
    });

    test('parses --flutter-sdk-path option', () {
      final runner = DevToolsCommandRunner();
      final results = runner.argParser.parse([
        '--flutter-sdk-path',
        '/custom/path',
      ]);
      expect(results['flutter-sdk-path'], equals('/custom/path'));
    });
  });

  group('FlutterSdk.findFromPath', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_sdk_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('finds SDK root from bin/flutter executable path', () {
      final binDir = Directory(path.join(tempDir.path, 'bin'))..createSync();
      final flutterExe = File(path.join(binDir.path, 'flutter'))..createSync();

      final sdk = FlutterSdk.findFromPath(flutterExe.path);
      expect(sdk.sdkPath, equals(tempDir.resolveSymbolicLinksSync()));
    });

    test('resolves symbolic links to find actual SDK root', () {
      final sdkDir = Directory(path.join(tempDir.path, 'real_sdk'))
        ..createSync();
      final binDir = Directory(path.join(sdkDir.path, 'bin'))..createSync();
      final flutterExe = File(path.join(binDir.path, 'flutter'))..createSync();

      final linkDir = Directory(path.join(tempDir.path, 'symlink_bin'))
        ..createSync();
      final symlink = Link(path.join(linkDir.path, 'flutter'));
      symlink.createSync(flutterExe.path);

      final sdk = FlutterSdk.findFromPath(symlink.path);
      expect(sdk.sdkPath, equals(sdkDir.resolveSymbolicLinksSync()));
    });

    test('finds SDK root when given SDK directory path directly', () {
      final binDir = Directory(path.join(tempDir.path, 'bin'))..createSync();
      File(path.join(binDir.path, 'flutter')).createSync();

      final sdk = FlutterSdk.findFromPath(tempDir.path);
      expect(sdk.sdkPath, equals(tempDir.resolveSymbolicLinksSync()));
    });

    test('throws Exception when unable to locate Flutter SDK', () {
      expect(
        () => FlutterSdk.findFromPath('/non/existent/path/to/flutter'),
        throwsA(isA<Exception>()),
      );
    });
  });
}

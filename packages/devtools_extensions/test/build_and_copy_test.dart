// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../bin/_build_and_copy.dart';

void main() {
  group('build_and_copy argParser', () {
    final command = BuildExtensionCommand();
    const requiredArgs = ['--source', 'src', '--dest', 'dest'];

    test('has backwards-compatible defaults', () {
      final results = command.argParser.parse(requiredArgs);
      expect(results['tree-shake-icons'], isFalse);
      expect(results['web-resources-cdn'], isTrue);
      expect(results['prune-cdn-canvaskit'], isFalse);
    });

    test('supports --tree-shake-icons', () {
      final results = command.argParser.parse([
        ...requiredArgs,
        '--tree-shake-icons',
      ]);
      expect(results['tree-shake-icons'], isTrue);
    });

    test('supports --no-web-resources-cdn for offline builds', () {
      final results = command.argParser.parse([
        ...requiredArgs,
        '--no-web-resources-cdn',
      ]);
      expect(results['web-resources-cdn'], isFalse);
    });

    test('supports --prune-cdn-canvaskit', () {
      final results = command.argParser.parse([
        ...requiredArgs,
        '--prune-cdn-canvaskit',
      ]);
      expect(results['prune-cdn-canvaskit'], isTrue);
    });

    test('rejects --prune-cdn-canvaskit with --no-web-resources-cdn', () {
      final runner = CommandRunner<void>('test', 'test')
        ..addCommand(BuildExtensionCommand());
      expect(
        runner.run([
          'build_and_copy',
          ...requiredArgs,
          '--no-web-resources-cdn',
          '--prune-cdn-canvaskit',
        ]),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('pruneCopiedBuildOutput', () {
    late Directory tempDir;
    late Directory buildDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('build_and_copy_test_');
      buildDir = Directory(p.join(tempDir.path, 'build'))..createSync();
      _writeFakeBuildOutput(buildDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    void expectRuntimeAssetsKept() {
      for (final filePath in [
        'canvaskit.js',
        'canvaskit.wasm',
        p.join('chromium', 'canvaskit.js'),
        p.join('chromium', 'canvaskit.wasm'),
        p.join('webparagraph', 'canvaskit.js'),
        p.join('webparagraph', 'canvaskit.wasm'),
      ]) {
        expect(
          File(p.join(buildDir.path, 'canvaskit', filePath)).existsSync(),
          isTrue,
          reason: '$filePath may be selected by the runtime configuration',
        );
      }
    }

    void expectSymbolsRemoved() {
      expect(
        Directory(p.join(buildDir.path, 'canvaskit'))
            .listSync(recursive: true)
            .whereType<File>()
            .any((file) => file.path.endsWith('.js.symbols')),
        isFalse,
        reason: '.js.symbols files are never fetched at runtime',
      );
    }

    void expectWasmRendererRemoved() {
      for (final filePath in [
        'skwasm.js',
        'skwasm.wasm',
        'skwasm_heavy.js',
        'skwasm_heavy.wasm',
        'wimp.js',
      ]) {
        expect(
          File(p.join(buildDir.path, 'canvaskit', filePath)).existsSync(),
          isFalse,
          reason:
              '$filePath is unreachable without a main.dart.wasm '
              'application artifact',
        );
      }
    }

    void expectOtherOutputIntact() {
      expect(File(p.join(buildDir.path, 'index.html')).existsSync(), isTrue);
      expect(File(p.join(buildDir.path, 'main.dart.js')).existsSync(), isTrue);
    }

    test('default keeps all runtime CanvasKit variants', () {
      BuildExtensionCommand.pruneCopiedBuildOutput(
        buildDir.path,
        pruneCdnCanvasKit: false,
      );

      expectSymbolsRemoved();
      expectWasmRendererRemoved();
      expectRuntimeAssetsKept();
      expectOtherOutputIntact();
    });

    test('default keeps wasm renderer when main.dart.wasm exists', () {
      // A dart2wasm build emits main.dart.wasm at the build root, so the
      // wasm renderer is reachable regardless of configuration contents.
      File(
        p.join(buildDir.path, 'main.dart.wasm'),
      ).writeAsStringSync('// wasm');

      BuildExtensionCommand.pruneCopiedBuildOutput(
        buildDir.path,
        pruneCdnCanvasKit: false,
      );

      expectSymbolsRemoved();
      for (final filePath in [
        'skwasm.js',
        'skwasm.wasm',
        'skwasm_heavy.js',
        'skwasm_heavy.wasm',
        'wimp.js',
      ]) {
        expect(
          File(p.join(buildDir.path, 'canvaskit', filePath)).existsSync(),
          isTrue,
          reason: 'a wasm application artifact exists in this output',
        );
      }
      expectRuntimeAssetsKept();
    });

    test('default keeps wasm renderer for content-hashed wasm artifacts', () {
      // Future Flutter versions may emit content-hashed artifact names;
      // any .wasm application artifact at the build root proves the wasm
      // renderer is reachable.
      File(
        p.join(buildDir.path, 'main.dart.abcdef12.wasm'),
      ).writeAsStringSync('// wasm');

      BuildExtensionCommand.pruneCopiedBuildOutput(
        buildDir.path,
        pruneCdnCanvasKit: false,
      );

      expect(
        File(p.join(buildDir.path, 'canvaskit', 'skwasm.wasm')).existsSync(),
        isTrue,
        reason: 'a wasm application artifact exists in this output',
      );
      expectRuntimeAssetsKept();
    });

    test('--prune-cdn-canvaskit removes the entire canvaskit directory', () {
      BuildExtensionCommand.pruneCopiedBuildOutput(
        buildDir.path,
        pruneCdnCanvasKit: true,
      );

      expect(
        Directory(p.join(buildDir.path, 'canvaskit')).existsSync(),
        isFalse,
        reason: 'the caller asserted all engine resources load from the CDN',
      );
      expectOtherOutputIntact();
    });

    test('does nothing when the canvaskit directory is absent', () {
      Directory(p.join(buildDir.path, 'canvaskit')).deleteSync(recursive: true);

      BuildExtensionCommand.pruneCopiedBuildOutput(
        buildDir.path,
        pruneCdnCanvasKit: true,
      );

      expectOtherOutputIntact();
    });

    test('works without a bootstrap file', () {
      // The pruning decision never depends on flutter_bootstrap.js.
      BuildExtensionCommand.pruneCopiedBuildOutput(
        buildDir.path,
        pruneCdnCanvasKit: false,
      );

      expectSymbolsRemoved();
      expectWasmRendererRemoved();
      expectRuntimeAssetsKept();
    });

    group('retains assets for configuration that cannot be proven safe', () {
      for (final (description, contents) in [
        (
          'a config object reassigned after the emitted statement',
          '_flutter.buildConfig = {"engineRevision":"abc123","builds":[]};\n'
              '_flutter.buildConfig = runtimeOffline;\n'
              '_flutter.loader.load({});\n',
        ),
        (
          'a mutated build configuration',
          '_flutter.buildConfig = {"engineRevision":"abc123","builds":[]};\n'
              '_flutter.buildConfig.useLocalCanvasKit = true;\n'
              '_flutter.loader.load({});\n',
        ),
        (
          'an escaped configuration option key',
          '_flutter.buildConfig = {"engineRevision":"abc123","builds":[]};\n'
              r'_flutter.loader.load({conf\u0069g: {canvasKitBaseUrl: "./"}});'
              '\n',
        ),
        (
          'a getter configuration option',
          '_flutter.buildConfig = {"engineRevision":"abc123","builds":[]};\n'
              '_flutter.loader.load({'
              'get config() { return window.runtimeOptions; }});\n',
        ),
        (
          'a dynamically appended wasm build entry',
          '_flutter.buildConfig = {"engineRevision":"abc123","builds":'
              '[{"compileTarget":"dart2js","renderer":"canvaskit"}]};\n'
              '_flutter.buildConfig.builds.push('
              '{"compileTarget":"dart2wasm"});\n'
              '_flutter.loader.load({});\n',
        ),
      ]) {
        test(description, () {
          File(
            p.join(buildDir.path, 'flutter_bootstrap.js'),
          ).writeAsStringSync(contents);
          // A wasm artifact exists, so the wasm renderer is reachable.
          File(
            p.join(buildDir.path, 'main.dart.wasm'),
          ).writeAsStringSync('// wasm');

          BuildExtensionCommand.pruneCopiedBuildOutput(
            buildDir.path,
            pruneCdnCanvasKit: false,
          );

          expectSymbolsRemoved();
          expectRuntimeAssetsKept();
          expect(
            File(
              p.join(buildDir.path, 'canvaskit', 'skwasm.wasm'),
            ).existsSync(),
            isTrue,
          );
        });
      }

      test('a canvasKitBaseUrl in index.html initialization', () {
        File(p.join(buildDir.path, 'index.html')).writeAsStringSync(
          '<script>_flutter.loader.load({config: {'
          'canvasKitBaseUrl: "canvaskit/"}});</script>',
        );

        BuildExtensionCommand.pruneCopiedBuildOutput(
          buildDir.path,
          pruneCdnCanvasKit: false,
        );

        expectRuntimeAssetsKept();
      });
    });
  });
}

/// Writes a `build/web`-like directory containing every canvaskit variant
/// that `flutter build web` produces.
void _writeFakeBuildOutput(Directory buildDir) {
  File(p.join(buildDir.path, 'index.html')).writeAsStringSync('<html></html>');
  File(p.join(buildDir.path, 'main.dart.js')).writeAsStringSync('// js');
  final canvaskitDir = Directory(p.join(buildDir.path, 'canvaskit'));
  for (final filePath in [
    'canvaskit.js',
    'canvaskit.wasm',
    'canvaskit.js.symbols',
    'skwasm.js',
    'skwasm.wasm',
    'skwasm.js.symbols',
    'skwasm_heavy.js',
    'skwasm_heavy.wasm',
    'skwasm_heavy.js.symbols',
    'wimp.js',
    'wimp.js.symbols',
    p.join('chromium', 'canvaskit.js'),
    p.join('chromium', 'canvaskit.wasm'),
    p.join('chromium', 'canvaskit.js.symbols'),
    p.join('webparagraph', 'canvaskit.js'),
    p.join('webparagraph', 'canvaskit.wasm'),
    p.join('webparagraph', 'canvaskit.js.symbols'),
  ]) {
    final file = File(p.join(canvaskitDir.path, filePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('fake $filePath');
  }
}

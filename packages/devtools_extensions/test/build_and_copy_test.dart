// Copyright 2026 The Flutter Authors
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
      expect(results['prune-local-canvaskit'], isFalse);
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

    test('supports --prune-local-canvaskit', () {
      final results = command.argParser.parse([
        ...requiredArgs,
        '--prune-local-canvaskit',
      ]);
      expect(results['prune-local-canvaskit'], isTrue);
    });

    test('rejects --prune-local-canvaskit with --no-web-resources-cdn', () {
      final runner = CommandRunner<void>('test', 'test')
        ..addCommand(BuildExtensionCommand());
      expect(
        runner.run([
          'build_and_copy',
          ...requiredArgs,
          '--no-web-resources-cdn',
          '--prune-local-canvaskit',
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
      for (final filePath in _wasmRendererFiles) {
        expect(
          File(p.join(buildDir.path, 'canvaskit', filePath)).existsSync(),
          isFalse,
          reason: '$filePath is unreachable for this build configuration',
        );
      }
    }

    void expectWasmRendererKept() {
      for (final filePath in _wasmRendererFiles) {
        expect(
          File(p.join(buildDir.path, 'canvaskit', filePath)).existsSync(),
          isTrue,
          reason:
              '$filePath may be selected by a skwasm renderer build '
              'configuration',
        );
      }
    }

    void expectOtherOutputIntact() {
      expect(File(p.join(buildDir.path, 'index.html')).existsSync(), isTrue);
      expect(File(p.join(buildDir.path, 'main.dart.js')).existsSync(), isTrue);
    }

    void pruneDefault() {
      BuildExtensionCommand.pruneCopiedBuildOutput(
        buildDir.path,
        pruneLocalCanvasKit: false,
      );
    }

    test('default prunes skwasm/wimp for a dart2js canvaskit build', () {
      // Configuration emitted by `flutter build web` (dart2js + CanvasKit).
      // Note that `wasmHashes` lists skwasm hashes even for this build, so it
      // must not influence the pruning decision.
      _writeFlutterBootstrap(
        buildDir,
        _flutterBuildConfigScript(_dart2jsCanvasKitBuilds),
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererRemoved();
      expectRuntimeAssetsKept();
      expectOtherOutputIntact();
    });

    test('default keeps skwasm/wimp for a dart2js skwasm build without a '
        'wasm artifact', () {
      // `flutter build web` with
      // `--dart-define=FLUTTER_WEB_USE_SKIA=false
      //  --dart-define=FLUTTER_WEB_USE_SKWASM=true` emits a dart2js build
      // targeting the skwasm renderer with no root-level .wasm artifact.
      _writeFlutterBootstrap(
        buildDir,
        _flutterBuildConfigScript(_dart2jsSkwasmBuilds),
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
      expectRuntimeAssetsKept();
      expectOtherOutputIntact();
    });

    test('default keeps skwasm/wimp for dart2wasm skwasm and dart2js canvaskit '
        'builds', () {
      // Configuration emitted by `flutter build web --wasm`, which
      // contains both a dart2wasm/skwasm and a dart2js/canvaskit build.
      _writeFlutterBootstrap(
        buildDir,
        _flutterBuildConfigScript(_dart2wasmSkwasmAndCanvasKitBuilds),
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
      expectRuntimeAssetsKept();
      expectOtherOutputIntact();
    });

    test('default keeps everything when no build config exists', () {
      // Without a readable `_flutter.buildConfig` the renderer selection
      // cannot be proven, so pruning must fail closed. The fake build output
      // contains neither flutter_bootstrap.js nor an inlined config.
      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
      expectRuntimeAssetsKept();
      expectOtherOutputIntact();
    });

    test('default keeps everything when the build config is malformed', () {
      _writeFlutterBootstrap(
        buildDir,
        '_flutter.buildConfig = {this is not: valid json,,};\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default keeps everything when the build config is dynamic', () {
      for (final contents in [
        '_flutter.buildConfig = JSON.parse(window.rawBuildConfig);\n',
        '_flutter.buildConfig = runtimeOfflineConfig;\n',
      ]) {
        _writeFlutterBootstrap(buildDir, contents);

        pruneDefault();

        expectSymbolsRemoved();
        expectWasmRendererKept();
        expectRuntimeAssetsKept();
      }
    });

    test('default keeps everything when builds is reassigned', () {
      _writeFlutterBootstrap(
        buildDir,
        '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
        '_flutter.buildConfig = runtimeOffline;\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default keeps everything when builds is mutated', () {
      _writeFlutterBootstrap(
        buildDir,
        '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
        '_flutter.buildConfig.builds.push('
        '{"compileTarget":"dart2wasm","renderer":"skwasm"});\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default keeps everything when builds is accessed dynamically', () {
      _writeFlutterBootstrap(
        buildDir,
        '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
        '_flutter.buildConfig["bui" + "lds"] = extraBuilds;\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test(
      'default keeps everything when builds is mutated through an alias',
      () {
        // The configuration object escapes through a plain read, so mutations
        // through the alias are invisible to per-token checks and must be
        // caught by the file-wide builds-access scan.
        _writeFlutterBootstrap(
          buildDir,
          '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
          'const config = _flutter.buildConfig;\n'
          'config.builds.push('
          '{"compileTarget":"dart2js","renderer":"skwasm"});\n',
        );

        pruneDefault();

        expectSymbolsRemoved();
        expectWasmRendererKept();
      },
    );

    test(
      'default keeps everything when builds is replaced through an alias',
      () {
        _writeFlutterBootstrap(
          buildDir,
          '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
          'const config = _flutter.buildConfig;\n'
          'config.builds = [{"compileTarget":"dart2js",'
          '"renderer":"skwasm"}];\n',
        );

        pruneDefault();

        expectSymbolsRemoved();
        expectWasmRendererKept();
      },
    );

    test('default keeps everything when builds is mutated through '
        'destructuring', () {
      _writeFlutterBootstrap(
        buildDir,
        '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
        'const {builds} = _flutter.buildConfig;\n'
        'builds.push({"compileTarget":"dart2js","renderer":"skwasm"});\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default keeps everything when builds is mutated through '
        'Object.assign', () {
      _writeFlutterBootstrap(
        buildDir,
        '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
        'Object.assign(_flutter.buildConfig, {builds: [{'
        '"compileTarget":"dart2js","renderer":"skwasm"}]});\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default keeps everything when builds is mutated through a '
        'computed member', () {
      _writeFlutterBootstrap(
        buildDir,
        '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
        'const config = _flutter.buildConfig;\n'
        'config["builds"].push('
        '{"compileTarget":"dart2js","renderer":"skwasm"});\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default keeps everything when a builds entry is mutated in a '
        'for-of loop', () {
      _writeFlutterBootstrap(
        buildDir,
        '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
        'const config = _flutter.buildConfig;\n'
        'for (const build of config.builds) {\n'
        '  build.renderer = "skwasm";\n'
        '}\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default keeps everything when buildConfig is replaced through '
        'Object.defineProperty', () {
      _writeFlutterBootstrap(
        buildDir,
        '${_flutterBuildConfigScript(_dart2jsCanvasKitBuilds)}'
        'Object.defineProperty(_flutter, "buildConfig", '
        '{value: {builds: []}});\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default keeps everything when the config is reached through '
        'globalThis', () {
      _writeFlutterBootstrap(
        buildDir,
        'globalThis._flutter.buildConfig = ${_buildsJson(_dart2jsCanvasKitBuilds)};\n'
        'const config = globalThis._flutter.buildConfig;\n'
        'config.builds.push('
        '{"compileTarget":"dart2js","renderer":"skwasm"});\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('default still prunes when the loader only reads builds in a '
        'for-of loop', () {
      // Mirrors the real flutter_bootstrap.js loader: it aliases the config
      // and iterates `builds` read-only.
      _writeFlutterBootstrap(
        buildDir,
        'let i = _flutter.buildConfig;\n'
        'for (const build of i.builds) {\n'
        '  console.log(build.compileTarget, build.renderer);\n'
        '}\n'
        '_flutter.buildConfig = ${_buildsJson(_dart2jsCanvasKitBuilds)};\n',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererRemoved();
      expectRuntimeAssetsKept();
      expectOtherOutputIntact();
    });

    test('reads a build config inlined in index.html', () {
      // Templates that use {{flutter_build_config}} inline the configuration
      // into index.html instead of referencing flutter_bootstrap.js.
      File(p.join(buildDir.path, 'index.html')).writeAsStringSync(
        '<script>${_flutterBuildConfigScript(_dart2jsSkwasmBuilds)}</script>',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('keeps everything when any discovered config uses skwasm', () {
      _writeFlutterBootstrap(
        buildDir,
        _flutterBuildConfigScript(_dart2jsCanvasKitBuilds),
      );
      File(p.join(buildDir.path, 'index.html')).writeAsStringSync(
        '<script>${_flutterBuildConfigScript(_dart2jsSkwasmBuilds)}</script>',
      );

      pruneDefault();

      expectSymbolsRemoved();
      expectWasmRendererKept();
    });

    test('--prune-local-canvaskit removes the entire canvaskit directory', () {
      _writeFlutterBootstrap(
        buildDir,
        _flutterBuildConfigScript(_dart2jsCanvasKitBuilds),
      );

      BuildExtensionCommand.pruneCopiedBuildOutput(
        buildDir.path,
        pruneLocalCanvasKit: true,
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
        pruneLocalCanvasKit: true,
      );

      expectOtherOutputIntact();
    });
  });
}

const _wasmRendererFiles = [
  'skwasm.js',
  'skwasm.wasm',
  'skwasm_heavy.js',
  'skwasm_heavy.wasm',
  'wimp.js',
  'wimp.wasm',
];

// `builds` values below mirror the JSON emitted into `_flutter.buildConfig`
// by `flutter build web` (see `buildConfigString` in flutter_tools'
// web.dart). The dart2js/skwasm entry is what
// `--dart-define=FLUTTER_WEB_USE_SKIA=false
// --dart-define=FLUTTER_WEB_USE_SKWASM=true` produces for a dart2js build.
const _dart2jsCanvasKitBuilds =
    '[{"compileTarget":"dart2js","renderer":"canvaskit",'
    '"mainJsPath":"main.dart.js"},{}]';
const _dart2jsSkwasmBuilds =
    '[{"compileTarget":"dart2js","renderer":"skwasm",'
    '"mainJsPath":"main.dart.js"},{}]';
const _dart2wasmSkwasmAndCanvasKitBuilds =
    '[{"compileTarget":"dart2wasm","renderer":"skwasm",'
    '"mainWasmPath":"main.dart.wasm","jsSupportRuntimePath":"main.dart.mjs"},'
    '{"compileTarget":"dart2js","renderer":"canvaskit",'
    '"mainJsPath":"main.dart.js"}]';

/// A `_flutter.buildConfig` JSON object with a realistic `wasmHashes` map,
/// which lists engine wasm integrity hashes for every variant regardless of
/// the renderer selected by `builds`.
String _buildsJson(String builds) =>
    '{"engineRevision":"692136cb6582dbfc5af3fb33c2515a069f2f66d0",'
    '"wasmHashes":{"skwasm.wasm":"e540fd5e8303b7b68ec2718cb49e9c421f8ade'
    '3075b15e02a7059a62654df9a1"},'
    '"builds":$builds,"useLocalCanvasKit":true}';

/// A `flutter_bootstrap.js`-like file: the loader reads the configuration
/// before it is assigned, then the emitted literal assigns it.
String _flutterBuildConfigScript(String builds) =>
    'let i = _flutter.buildConfig;\n'
    '_flutter.buildConfig = ${_buildsJson(builds)};\n';

void _writeFlutterBootstrap(Directory buildDir, String contents) {
  File(
    p.join(buildDir.path, 'flutter_bootstrap.js'),
  ).writeAsStringSync(contents);
}

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
    'wimp.wasm',
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

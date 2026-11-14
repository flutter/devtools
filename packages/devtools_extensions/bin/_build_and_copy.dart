// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// The result of inspecting one file for `_flutter.buildConfig` literals.
///
/// `foundConfig` is true when at least one well-formed configuration literal
/// was found; `renderers` contains the `renderer` values of every `builds`
/// entry across all discovered literals. A null result means the
/// configuration cannot be statically proven safe.
typedef _BuildConfigInspection = ({bool foundConfig, Set<String> renderers});

/// Command that builds a DevTools extension and copies the built output to
/// the parent package extension location.
///
/// Example usage:
///
/// dart run devtools_extensions build_and_copy \
///  --source=path/to/your_extension_web_app \
///  --dest=path/to/your_pub_package/extension/devtools
class BuildExtensionCommand extends Command {
  BuildExtensionCommand() {
    argParser
      ..addOption(
        _sourceKey,
        help:
            'The source location for the extension flutter web app (can  be '
            'relative or absolute)',
        valueHelp: 'path/to/foo/packages/foo_devtools_extension',
        mandatory: true,
      )
      ..addOption(
        _destinationKey,
        help:
            'The destination location for the extension build output (can be '
            'relative or absolute)',
        valueHelp: 'path/to/foo/packages/foo/extension/devtools',
        mandatory: true,
      )
      ..addFlag(
        _treeShakeIconsKey,
        help:
            'Allow the compiler to tree-shake the icon fonts used by the '
            'extension. This is disabled by default to preserve backwards '
            'compatibility for extensions that create IconData dynamically.',
      )
      ..addFlag(
        _webResourcesCdnKey,
        help:
            'Load web engine resources (e.g. CanvasKit) from the Google CDN '
            'instead of bundling them in the extension build output. Pass '
            '--no-web-resources-cdn to bundle the resources the extension '
            'needs locally instead (for example for offline use).',
        defaultsTo: true,
      )
      ..addFlag(
        _pruneLocalCanvasKitKey,
        help:
            'Delete the bundled canvaskit/ directory from the copied '
            'extension build output. Only use this when the app is known to '
            'load all web engine resources from the CDN at runtime: the '
            'default `flutter build web` configuration with no custom '
            'bootstrap, no custom index.html initialization, and no runtime '
            'configuration that could select local resources. Cannot be '
            'combined with --no-web-resources-cdn.',
      );
  }

  static const _commandName = 'build_and_copy';
  static const _sourceKey = 'source';
  static const _destinationKey = 'dest';
  static const _treeShakeIconsKey = 'tree-shake-icons';
  static const _webResourcesCdnKey = 'web-resources-cdn';
  static const _pruneLocalCanvasKitKey = 'prune-local-canvaskit';

  static const _canvaskitDirName = 'canvaskit';
  static const _jsSymbolsSuffix = '.js.symbols';
  static const _skwasmAssetPrefix = 'skwasm';
  static const _wimpAssetPrefix = 'wimp';
  static const _skwasmRendererName = 'skwasm';

  @override
  String get name => _commandName;

  @override
  String get description =>
      'Command that builds a DevTools extension from source and copies the '
      'built output to the parent package extension location.';

  @override
  Future<void> run() async {
    final source = argResults?[_sourceKey]! as String;
    final destination = argResults?[_destinationKey]! as String;
    final treeShakeIcons = argResults?[_treeShakeIconsKey] as bool;
    final webResourcesCdn = argResults?[_webResourcesCdnKey] as bool;
    final pruneLocalCanvasKit = argResults?[_pruneLocalCanvasKitKey] as bool;

    if (pruneLocalCanvasKit && !webResourcesCdn) {
      throw UsageException(
        '--$_pruneLocalCanvasKitKey cannot be combined with '
        '--no-$_webResourcesCdnKey because local CanvasKit resources are '
        'required when the CDN is disabled.',
        argParser.usage,
      );
    }

    final processManager = ProcessManager();

    _log('Building the extension Flutter web app...');
    await _runProcess(
      processManager,
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      [
        'build',
        'web',
        '--release',
        if (!treeShakeIcons) '--no-tree-shake-icons',
        if (!webResourcesCdn) '--no-web-resources-cdn',
      ],
      workingDirectory: source,
    );

    // TODO(kenz): investigate if we need to perform a windows equivalent of
    // `chmod` or if we even need to perform `chmod` for linux / mac anymore.
    if (!Platform.isWindows) {
      _log('Setting canvaskit permissions...');
      await _runProcess(processManager, 'chmod', [
        '0755',
        // Note: using a wildcard `canvaskit.*` throws.
        'build/web/canvaskit/canvaskit.js',
        'build/web/canvaskit/canvaskit.wasm',
      ], workingDirectory: source);
    }

    _log('Copying built output to the extension destination...');
    await _copyBuildToDestination(
      source: source,
      dest: destination,
      pruneLocalCanvasKit: pruneLocalCanvasKit,
    );
  }

  Future<void> _copyBuildToDestination({
    required String source,
    required String dest,
    required bool pruneLocalCanvasKit,
  }) async {
    _log('Replacing the existing extension build with the new one...');
    final sourceBuildPath = path.join(source, 'build', 'web');
    final destinationBuildPath = path.join(dest, 'build');

    final destinationDirectory = Directory(destinationBuildPath);
    if (destinationDirectory.existsSync()) {
      destinationDirectory.deleteSync(recursive: true);
    }
    Directory(destinationBuildPath).createSync(recursive: true);

    await copyPath(sourceBuildPath, destinationBuildPath);

    pruneCopiedBuildOutput(
      destinationBuildPath,
      pruneLocalCanvasKit: pruneLocalCanvasKit,
    );

    _log(
      'Successfully copied extension assets from '
      '"${Directory(source).resolveSymbolicLinksSync()}" to'
      '"${Directory(dest).resolveSymbolicLinksSync()}"',
    );
  }

  /// Removes files from the copied extension build output that are never
  /// requested at runtime (https://github.com/flutter/devtools/issues/9897).
  ///
  /// The Flutter tool copies every built web engine artifact into
  /// `canvaskit/`, including files a given build can never load. Assets are
  /// only removed when they are proven unreachable, or when the caller
  /// explicitly asserts they are not needed:
  ///
  /// * `.js.symbols` debug files are only used by development tooling and
  ///   are never fetched at runtime, so they are always removed.
  /// * `skwasm*`/`wimp*` renderer variants are removed only when every
  ///   `_flutter.buildConfig` found in `flutter_bootstrap.js` or
  ///   `index.html` provably contains no build with `"renderer": "skwasm"`.
  ///   The loader selects engine resources from that configuration, and a
  ///   Skwasm renderer can be selected by `dart2wasm` builds
  ///   (`flutter build web --wasm`) as well as by `dart2js` builds that opt
  ///   in through `--dart-define=FLUTTER_WEB_USE_SKIA=false
  ///   --dart-define=FLUTTER_WEB_USE_SKWASM=true` — neither of which requires
  ///   a root-level `.wasm` application artifact, so artifact presence alone
  ///   cannot prove the renderer is unreachable. When no readable
  ///   configuration is found, or any discovered configuration is dynamic,
  ///   malformed, or could be mutated at runtime — through reassignment,
  ///   `builds` access, aliases, destructuring, `Object.assign`/`Reflect`,
  ///   computed keys, or dynamic execution — the variants are kept. The
  ///   proof covers only the two inspected files; scripts loaded by the page
  ///   from other files are outside its scope.
  /// * The entire `canvaskit/` directory is removed only when
  ///   [pruneLocalCanvasKit] is enabled. Whether a build loads CanvasKit
  ///   locally or from the CDN depends on runtime configuration that cannot
  ///   be verified statically, so this aggressive prune is opt-in. Callers
  ///   must ensure the app uses the default `flutter build web` CDN
  ///   configuration with no custom bootstrap, `index.html` initialization,
  ///   or runtime configuration overrides.
  @visibleForTesting
  static void pruneCopiedBuildOutput(
    String destinationBuildPath, {
    required bool pruneLocalCanvasKit,
  }) {
    final canvaskitDir = Directory(
      path.join(destinationBuildPath, _canvaskitDirName),
    );
    if (!canvaskitDir.existsSync()) return;

    var prunedBytes = 0;

    if (pruneLocalCanvasKit) {
      // Opt-in aggressive prune: the caller asserts every engine resource
      // is loaded remotely at runtime.
      for (final entity in canvaskitDir.listSync(recursive: true)) {
        if (entity is File) prunedBytes += entity.lengthSync();
      }
      canvaskitDir.deleteSync(recursive: true);
    } else {
      // Debug symbols are never fetched at runtime in any build mode.
      for (final entity in canvaskitDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith(_jsSymbolsSuffix)) {
          prunedBytes += entity.lengthSync();
          entity.deleteSync();
        }
      }

      if (_canPruneSkwasmAssets(destinationBuildPath)) {
        // The local `canvaskit/`, `chromium/` and `webparagraph/` variants
        // are kept because the loader selects between them at runtime based
        // on browser support.
        for (final entity in canvaskitDir.listSync()) {
          if (entity is! File) continue;
          final name = path.basename(entity.path);
          if (name.startsWith(_skwasmAssetPrefix) ||
              name.startsWith(_wimpAssetPrefix)) {
            prunedBytes += entity.lengthSync();
            entity.deleteSync();
          }
        }
      }
    }

    if (prunedBytes > 0) {
      _log(
        'Pruned ${(prunedBytes / (1024 * 1024)).toStringAsFixed(1)} MB of '
        'engine resources that the extension never loads at runtime.',
      );
    }
  }

  /// Whether the `skwasm*`/`wimp*` engine variants in [buildPath] can be
  /// proven unreachable and removed.
  ///
  /// Returns false — keeping every variant — unless at least one readable
  /// `_flutter.buildConfig` is found across `flutter_bootstrap.js` and
  /// `index.html` and none of the discovered `builds` entries declare the
  /// `skwasm` renderer.
  static bool _canPruneSkwasmAssets(String buildPath) {
    var foundConfig = false;
    final renderers = <String>{};
    for (final fileName in const ['flutter_bootstrap.js', 'index.html']) {
      final file = File(path.join(buildPath, fileName));
      if (!file.existsSync()) continue;
      final inspection = _inspectBuildConfig(file.readAsStringSync());
      if (inspection == null) return false;
      foundConfig = foundConfig || inspection.foundConfig;
      renderers.addAll(inspection.renderers);
    }
    return foundConfig && !renderers.contains(_skwasmRendererName);
  }

  // Matches `_flutter.buildConfig` and `window._flutter.buildConfig`,
  // including optional-chaining (`?.`) and whitespace around the dots, and
  // prefixed forms such as `globalThis._flutter.buildConfig` (the lookbehind
  // only excludes identifier characters so that `foo._flutter.buildConfig`
  // is still inspected — over-inclusion only ever keeps assets).
  static final _buildConfigToken = RegExp(
    r'(?<![A-Za-z0-9_$])(?:window\s*\.\s*)?_flutter\s*'
    r'(?:\?\s*\.\s*|\.\s*)buildConfig(?![A-Za-z0-9_$])',
  );

  // Matches access to the `builds` property or any computed property access
  // on `_flutter.buildConfig`, which could mutate the configuration that the
  // static analysis below relies on.
  static final _buildsAccessPattern = RegExp(
    r'^\s*(?:(?:\?\s*\.\s*|\.\s*)builds\b|(?:\?\.)?\s*\[)',
  );

  // A value-position continuation directly after a non-assignment
  // `_flutter.buildConfig` reference — an argument or literal separator
  // (`,`, `)`, `]`, `}`), a ternary/case colon, a logical or bitwise operator,
  // or a `??` that is not optional chaining — means the object escapes into a
  // context where it could be mutated through an alias that the per-token
  // checks cannot see. Property reads (`.x`, `?.x`) and statement ends (`;`)
  // are the only continuations that cannot leak the object itself.
  static final _configEscapePattern = RegExp(
    r'^\s*(?:[,\)\]}:&|]|\?(?!\s*\.))',
  );

  // Dynamic code execution cannot be analyzed statically.
  static final _dynamicExecutionPattern = RegExp(
    r'\beval\s*\(|new\s+Function\s*\(|\bFunction\s*\(\s*[\x27\x22]|\bwith\s*\(|'
    r'(?:setTimeout|setInterval|setImmediate)\s*\(\s*[\x27\x22]',
  );

  // Computed access to the configuration object itself, which bypasses the
  // `_flutter.buildConfig` token entirely.
  static final _computedConfigAccessPattern = RegExp(
    r'(?:window|globalThis|self|top|parent|frames)\s*(?:\?\s*\.\s*)?'
    r'\[\s*[\x27\x22]_flutter[\x27\x22]'
    r'|(?:window\s*\.\s*)?_flutter\s*(?:\?\s*\.\s*)?\[\s*[\x27\x22](?:buildConfig|builds)[\x27\x22]',
  );

  // `Object.*`/`Reflect.*` calls that could replace or mutate `builds` or
  // `buildConfig` through a string key. Read-only lookups such as
  // `Object.keys` are intentionally not matched.
  static final _objectBuildsMutationPattern = RegExp(
    r'Object\s*\.\s*(?:assign|definePropert\w*|setPrototypeOf)\s*'
    r'\([^;{}]{0,200}?[\x27\x22](?:builds|buildConfig)[\x27\x22]'
    r'|Reflect\s*\.\s*(?:set|definePropert\w*|deleteProperty)\s*'
    r'\([^;{}]{0,200}?[\x27\x22](?:builds|buildConfig)[\x27\x22]',
  );

  // Computed `builds` member access such as `config['builds']`,
  // `config?.['builds']`, or a computed object key `{['builds']: ...}`.
  static final _computedBuildsMemberPattern = RegExp(
    r'[\w$\)\].?{]\s*\[\s*[\x27\x22]builds[\x27\x22]\s*\]',
  );

  // An unquoted or quoted `builds`/`buildConfig` key or shorthand property in
  // an object literal, which could smuggle a replacement configuration into
  // `Object.assign` or similar. The parsed `_flutter.buildConfig` literals
  // are blanked out before this scan runs, so the emitted `"builds":[...]`
  // JSON key does not match.
  static final _buildsKeyPattern = RegExp(
    r'[{,]\s*(?:builds|buildConfig)\s*[:,}]'
    r'|[{,]\s*[\x27\x22](?:builds|buildConfig)[\x27\x22]\s*:',
  );

  // Destructuring that pulls `builds`/`buildConfig` out of an object, e.g.
  // `const {builds} = config` or `const {builds: b} = config`.
  static final _buildsDestructurePattern = RegExp(
    r'\{[^{}]*\b(?:builds|buildConfig)\b[^{}]*\}\s*=(?![=>])',
  );

  // Any `.builds`/`?.builds` property access anywhere in the file.
  static final _buildsPropertyAccessPattern = RegExp(
    r'(?:\?\s*\.\s*|\.\s*)builds\b',
  );

  // The only provably safe `.builds` use: iterating the entries of a
  // `for...of` loop over a declared loop variable. The loop body is verified
  // separately to not mutate the entries.
  static final _safeBuildsIterationPattern = RegExp(
    r'for\s*(?:await\s+)?\(\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s+of\s+'
    r'[A-Za-z_$][\w$]*\s*(?:\?\s*\.\s*|\.\s*)builds\s*\)',
  );

  /// Statically extracts the renderer values of every
  /// `_flutter.buildConfig = {...}` literal in [content].
  ///
  /// Returns null when the configuration cannot be proven safe: a
  /// non-literal assignment (for example `_flutter.buildConfig =
  /// runtimeConfig`), malformed JSON, a `builds` value that is not a list of
  /// objects, code that reads or mutates `builds` outside the emitted
  /// literals, or code that could mutate the configuration through an alias,
  /// destructuring, `Object.assign`/`Reflect`, computed keys, or dynamic
  /// execution. The configuration object can escape the literal through
  /// plain reads (the Flutter loader itself does `let i =
  /// _flutter.buildConfig`), so every `.builds` access in the file must be a
  /// read-only `for...of` iteration whose body does not write to the loop
  /// variable.
  ///
  /// This is necessarily a heuristic: code in other files loaded by the page,
  /// `eval`-free computed keys (for example `config['bui' + 'lds']`), and
  /// mutations performed inside functions receiving the configuration or a
  /// `builds` entry through a parameter cannot be ruled out. Those cases are
  /// the documented limit of the static proof; everything detectable in the
  /// two inspected files fails closed and keeps the engine variants.
  static _BuildConfigInspection? _inspectBuildConfig(String content) {
    var foundConfig = false;
    final renderers = <String>{};
    final literalRanges = <(int, int)>[];
    for (final match in _buildConfigToken.allMatches(content)) {
      final rest = content.substring(match.end);
      final assignment = RegExp(r'^\s*=(?![=>])').firstMatch(rest);
      if (assignment == null) {
        if (_buildsAccessPattern.hasMatch(rest) ||
            _configEscapePattern.hasMatch(rest)) {
          return null;
        }
        continue;
      }
      final rhs = rest.substring(assignment.end);
      final openBrace = rhs.indexOf('{');
      if (openBrace < 0 || rhs.substring(0, openBrace).trim().isNotEmpty) {
        return null;
      }
      final jsonText = _extractJsonObject(rhs, openBrace);
      if (jsonText == null) return null;
      final Object? decoded;
      try {
        decoded = jsonDecode(jsonText);
      } on FormatException {
        return null;
      }
      if (decoded is! Map) return null;
      final builds = decoded['builds'];
      if (builds is! List) return null;
      foundConfig = true;
      for (final entry in builds) {
        if (entry is! Map) return null;
        final renderer = entry['renderer'];
        if (renderer is String) renderers.add(renderer);
      }
      final literalStart = match.end + assignment.end + openBrace;
      literalRanges.add((literalStart, literalStart + jsonText.length));
    }
    if (_hasUnsafeBuildsMutation(_blankRanges(content, literalRanges))) {
      return null;
    }
    return (foundConfig: foundConfig, renderers: renderers);
  }

  /// Whether [content] (with the parsed config literals already blanked out)
  /// contains code that could add, replace, or mutate `builds` entries or the
  /// `buildConfig` object itself.
  static bool _hasUnsafeBuildsMutation(String content) {
    return _dynamicExecutionPattern.hasMatch(content) ||
        _computedConfigAccessPattern.hasMatch(content) ||
        _objectBuildsMutationPattern.hasMatch(content) ||
        _computedBuildsMemberPattern.hasMatch(content) ||
        _buildsKeyPattern.hasMatch(content) ||
        _buildsDestructurePattern.hasMatch(content) ||
        _hasUnsafeBuildsPropertyAccess(content);
  }

  /// Whether [content] contains a `.builds` access that is not a read-only
  /// `for...of` iteration, or a `for...of` iteration whose body writes to the
  /// loop variable (which would mutate a `builds` entry in place).
  static bool _hasUnsafeBuildsPropertyAccess(String content) {
    final safeSpans = <(int, int)>[];
    for (final match in _safeBuildsIterationPattern.allMatches(content)) {
      final buildsAccess = _buildsPropertyAccessPattern.firstMatch(
        match.group(0)!,
      );
      if (buildsAccess != null) {
        safeSpans.add((
          match.start + buildsAccess.start,
          match.start + buildsAccess.end,
        ));
      }
      final body = _extractForBody(content, match.end);
      final loopVariable = match.group(1);
      if (body == null ||
          loopVariable == null ||
          _hasLoopVariableWrite(body, loopVariable)) {
        return true;
      }
    }
    for (final match in _buildsPropertyAccessPattern.allMatches(content)) {
      final isSafeIteration = safeSpans.any(
        (span) => match.start >= span.$1 && match.start < span.$2,
      );
      if (!isSafeIteration) return true;
    }
    return false;
  }

  /// Returns the brace-delimited body of the `for` statement whose header
  /// ends at [headerEnd], or null when the body is not a brace block (which
  /// cannot be verified and therefore fails closed).
  static String? _extractForBody(String content, int headerEnd) {
    var i = headerEnd;
    while (i < content.length && _isJsWhitespace(content.codeUnitAt(i))) {
      i++;
    }
    if (i >= content.length || content.codeUnitAt(i) != 0x7B) return null;
    return _extractJsBraceBlock(content, i);
  }

  /// Whether [body] (the text inside a `for...of` loop over `builds`)
  /// contains writes to [loopVariable]'s properties or index, or passes it
  /// to APIs that could mutate it.
  static bool _hasLoopVariableWrite(String body, String loopVariable) {
    final variable = RegExp.escape(loopVariable);
    final propertyWrite = RegExp(
      '\\b$variable\\s*(?:\\?\\s*\\.\\s*|\\.\\s*)[A-Za-z_\$][\\w\$]*'
      '(?:\\s*(?:\\?\\s*\\.\\s*|\\.\\s*)[A-Za-z_\$][\\w\$]*'
      '|\\s*(?:\\?\\s*\\.)?\\[[^\\]\\n]{0,40}\\])*\\s*'
      '(?:\\?\\s*)?(?:(?:&&|\\|\\||\\?\\?|<<|>>>?|[-+*/%&|^])?=(?![=>])'
      '|\\+\\+|--)',
    );
    final indexAccess = RegExp('\\b$variable\\s*(?:\\?\\s*\\.\\s*)?\\[');
    final objectMutation = RegExp(
      '\\b(?:Object\\s*\\.\\s*(?:assign|definePropert\\w*)'
      '|Reflect\\s*\\.\\s*\\w+|delete)\\b[^;{}\\n]{0,80}?\\b$variable\\b',
    );
    return propertyWrite.hasMatch(body) ||
        indexAccess.hasMatch(body) ||
        objectMutation.hasMatch(body);
  }

  /// Returns the contents of the brace-delimited block starting at the `{`
  /// at [openBraceIndex], skipping over JavaScript strings, template
  /// literals, comments, and regex literals. Returns null when the block
  /// never closes.
  static String? _extractJsBraceBlock(String content, int openBraceIndex) {
    const normal = 0, singleQuote = 1, doubleQuote = 2, template = 3;
    const lineComment = 4, blockComment = 5, regex = 6;
    var state = normal;
    var inRegexClass = false;
    var escaped = false;
    var depth = 0;
    for (var i = openBraceIndex; i < content.length; i++) {
      final unit = content.codeUnitAt(i);
      final next = i + 1 < content.length ? content.codeUnitAt(i + 1) : -1;
      switch (state) {
        case normal:
          if (unit == 0x7B) {
            depth++;
          } else if (unit == 0x7D) {
            depth--;
            if (depth == 0) {
              return content.substring(openBraceIndex + 1, i);
            }
          } else if (unit == 0x27) {
            state = singleQuote;
          } else if (unit == 0x22) {
            state = doubleQuote;
          } else if (unit == 0x60) {
            state = template;
          } else if (unit == 0x2F && next == 0x2F) {
            state = lineComment;
            i++;
          } else if (unit == 0x2F && next == 0x2A) {
            state = blockComment;
            i++;
          } else if (unit == 0x2F && _regexAllowedBefore(content, i)) {
            state = regex;
            inRegexClass = false;
          }
        case singleQuote:
          if (escaped) {
            escaped = false;
          } else if (unit == 0x5C) {
            escaped = true;
          } else if (unit == 0x27) {
            state = normal;
          }
        case doubleQuote:
          if (escaped) {
            escaped = false;
          } else if (unit == 0x5C) {
            escaped = true;
          } else if (unit == 0x22) {
            state = normal;
          }
        case template:
          if (escaped) {
            escaped = false;
          } else if (unit == 0x5C) {
            escaped = true;
          } else if (unit == 0x60) {
            state = normal;
          }
        case lineComment:
          if (unit == 0x0A) state = normal;
        case blockComment:
          if (unit == 0x2A && next == 0x2F) {
            state = normal;
            i++;
          }
        case regex:
          if (escaped) {
            escaped = false;
          } else if (unit == 0x5C) {
            escaped = true;
          } else if (unit == 0x5B) {
            inRegexClass = true;
          } else if (unit == 0x5D) {
            inRegexClass = false;
          } else if (unit == 0x2F && !inRegexClass) {
            state = normal;
          } else if (unit == 0x0A) {
            return null;
          }
      }
    }
    return null;
  }

  /// Whether a `/` at [slashIndex] is more likely to start a regex literal
  /// than to be a division operator, based on the preceding token.
  static bool _regexAllowedBefore(String content, int slashIndex) {
    var i = slashIndex - 1;
    while (i >= 0 && _isJsWhitespace(content.codeUnitAt(i))) {
      i--;
    }
    if (i < 0) return true;
    final unit = content.codeUnitAt(i);
    // After an operand (identifier char, closing bracket, quote, digit) a
    // slash is division; after an operator, keyword, or opening token it is
    // a regex.
    if ((unit >= 0x30 && unit <= 0x39) ||
        (unit >= 0x41 && unit <= 0x5A) ||
        (unit >= 0x61 && unit <= 0x7A) ||
        unit == 0x5F ||
        unit == 0x24 ||
        unit == 0x29 ||
        unit == 0x5D ||
        unit == 0x22 ||
        unit == 0x27 ||
        unit == 0x60) {
      // Identifier characters could still end in a keyword like `return`.
      final wordEnd = i + 1;
      var wordStart = i;
      while (wordStart > 0 &&
          _isJsIdentifierChar(content.codeUnitAt(wordStart - 1))) {
        wordStart--;
      }
      if (wordStart < wordEnd) {
        final word = content.substring(wordStart, wordEnd);
        return const {
          'return',
          'typeof',
          'case',
          'in',
          'of',
          'new',
          'delete',
          'void',
          'throw',
          'else',
          'do',
          'yield',
          'await',
          'instanceof',
        }.contains(word);
      }
      return false;
    }
    return true;
  }

  static bool _isJsWhitespace(int unit) =>
      unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;

  static bool _isJsIdentifierChar(int unit) =>
      (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A) ||
      unit == 0x5F ||
      unit == 0x24;

  /// Returns [content] with each `(start, end)` range replaced by spaces so
  /// that pattern scans do not match inside the already-parsed config
  /// literals.
  static String _blankRanges(String content, List<(int, int)> ranges) {
    if (ranges.isEmpty) return content;
    final buffer = StringBuffer();
    var position = 0;
    for (final (start, end) in ranges) {
      buffer
        ..write(content.substring(position, start))
        ..write(' ' * (end - start));
      position = end;
    }
    buffer.write(content.substring(position));
    return buffer.toString();
  }

  /// Returns the balanced `{...}` literal starting at the `{` at [start] in
  /// [content], or null when the braces never balance (for example inside a
  /// string that is never terminated).
  static String? _extractJsonObject(String content, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < content.length; i++) {
      final unit = content.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (unit == 0x5C) {
          escaped = true;
        } else if (unit == 0x22) {
          inString = false;
        }
        continue;
      }
      if (unit == 0x22) {
        inString = true;
      } else if (unit == 0x7B) {
        depth++;
      } else if (unit == 0x7D) {
        depth--;
        if (depth == 0) return content.substring(start, i + 1);
      }
    }
    return null;
  }

  static void _log(String message) =>
      stdout.writeln('[$_commandName] $message');

  Future<void> _runProcess(
    ProcessManager processManager,
    String exe,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final buildProcess = await processManager.spawn(
      exe,
      args,
      workingDirectory: workingDirectory,
    );
    final code = await buildProcess.exitCode;
    if (code != 0) {
      throw ProcessException(exe, args, 'Failed with exit code: $code', code);
    }
  }
}

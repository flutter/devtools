// Copyright 2023 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Note: this test was modeled after the example test from Flutter Gallery:
// https://github.com/flutter/gallery/blob/master/test_benchmarks/web_bundle_size_test.dart

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Benchmark size in kB.
const int bundleSizeBenchmark = 4800;
const int gzipBundleSizeBenchmark = 1400;

void main() {
  group('Web Compile', () {
    test(
      'bundle size',
      () async {
        final js = path.join(
          Directory.current.path,
          'build',
          'web',
          'main.dart.js',
        );

        _logStatus('Building DevTools web app in release mode...');
        // These build arguments match the arguments used in the
        // tool/lib/commands/build_release.dart command, which is how we build
        // DevTools for release.
        await _runProcess('flutter', [
          'build',
          'web',
          '--web-renderer',
          'canvaskit',
          '--pwa-strategy=offline-first',
          '--release',
          '--no-tree-shake-icons',
        ]);

        _logStatus('Zipping bundle with gzip...');
        await _runProcess('gzip', ['-k', '-f', js]);

        final bundleSize = await _measureSize(js);
        final gzipBundleSize = await _measureSize('$js.gz');
        if (bundleSize > bundleSizeBenchmark) {
          fail(
            'The size the compiled web build "$js" was $bundleSize kB. This is '
            'larger than the benchmark that was set at $bundleSizeBenchmark kB.'
            '\n\n'
            'The build size should be as minimal as possible to reduce the web '
            'app\'s initial startup time. If this change is intentional, and'
            ' expected, please increase the constant "bundleSizeBenchmark".',
          );
        } else if (gzipBundleSize > gzipBundleSizeBenchmark) {
          fail(
            'The size the compiled and gzipped web build "$js" was'
            ' $gzipBundleSize kB. This is larger than the benchmark that was '
            'set at $gzipBundleSizeBenchmark kB.\n\n'
            'The build size should be as minimal as possible to reduce the '
            'web app\'s initial startup time. If this change is intentional, '
            'and expected, please increase the constant '
            '"gzipBundleSizeBenchmark".',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}

Future<int> _measureSize(String file) async {
  final result = await _runProcess('du', ['-k', file]);
  return int.parse(
    (result.stdout as String).split(RegExp(r'\s+')).first.trim(),
  );
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(executable, arguments);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  return result;
}

void _logStatus(String log) {
  // ignore: avoid_print, expected log output.
  print(log);
}

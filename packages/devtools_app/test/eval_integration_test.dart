// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/eval_on_dart_library.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_testing/support/flutter_test_driver.dart';
import 'package:devtools_testing/support/flutter_test_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  Disposable isAlive;

  setUp(() {
    isAlive = Disposable();
  });

  tearDown(() async {
    isAlive.dispose();
    await env.tearDownEnvironment(force: true);
  });

  group('EvalOnDartLibrary', () {
    test('getHashCode', () async {
      await env.setupEnvironment();
      final eval = EvalOnDartLibrary('dart:core', serviceManager.service);

      final instance = await eval.safeEval('42', isAlive: isAlive);

      await expectLater(
        eval.getHashCode(instance, isAlive: isAlive),
        completion(anyOf(isPositive, 0)),
      );
    });

    group('asyncEval', () {
      test('supports expresions that do not start with the await keyword',
          () async {
        await env.setupEnvironment();

        final eval = EvalOnDartLibrary(
          'dart:core',
          serviceManager.service,
        );

        final instance = await eval.asyncEval('42', isAlive: isAlive);
        expect(instance.valueAsString, '42');

        final instance2 =
            await eval.asyncEval('Future.value(42)', isAlive: isAlive);
        expect(instance2.classRef.name, '_Future');
      });

      test('returns the result of the future completion', () async {
        await env.setupEnvironment();
        final mainIsolate = serviceManager.isolateManager.mainIsolate;
        expect(mainIsolate, isNotNull);

        final eval = EvalOnDartLibrary(
          'dart:core',
          serviceManager.service,
          isolate: mainIsolate,
        );

        final instance = await eval.asyncEval(
          // The delay asserts that there is no issue with garbage collection
          'await Future<int>.delayed(const Duration(milliseconds: 500), () => 42)',
          isAlive: isAlive,
        );

        expect(instance.valueAsString, '42');
      });

      test('throws FutureFailedException when the future is rejected',
          () async {
        await env.setupEnvironment();

        final eval = EvalOnDartLibrary(
          'dart:core',
          serviceManager.service,
        );

        final instance = await eval
            .asyncEval(
              'await Future.error(StateError("foo"), StackTrace.current)',
              isAlive: isAlive,
            )
            .then<FutureFailedException>(
              (_) => throw FallThroughError(),
              onError: (err) => err,
            );

        expect(
          instance.expression,
          'await Future.error(StateError("foo"), StackTrace.current)',
        );

        final stack = await eval.safeEval(
          'stack.toString()',
          isAlive: isAlive,
          scope: {
            'stack': instance.stacktraceRef.id,
          },
        );
        expect(
          stack.valueAsString,
          startsWith('#0      Eval.<anonymous closure> ()'),
        );

        final error = await eval.safeEval(
          'error.message',
          isAlive: isAlive,
          scope: {'error': instance.errorRef.id},
        );
        expect(error.valueAsString, 'foo');
      });
    });
  });
}

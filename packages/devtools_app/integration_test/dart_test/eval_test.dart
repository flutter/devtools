// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/eval_on_dart_library.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_utils.dart';

void main() {
  late Disposable isAlive;

  late TestApp testApp;

  setUpAll(() async {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
    await testApp.init();
  });

  setUp(() {
    isAlive = Disposable();
  });

  tearDown(() async {
    isAlive.dispose();
  });

  setUpAll(() async {
    await testApp.vmService.dispose();
  });

  group('EvalOnDartLibrary', () {
    test(
      'getHashCode',
      () async {
        final eval = EvalOnDartLibrary('dart:core', serviceManager.service!);

        final instance = await eval.safeEval('42', isAlive: isAlive);

        await expectLater(
          eval.getHashCode(instance, isAlive: isAlive),
          completion(anyOf(isPositive, 0)),
        );
      },
      timeout: const Timeout.factor(8),
    );

    group('asyncEval', () {
      test(
        'supports expresions that do not start with the await keyword',
        () async {
          final eval = EvalOnDartLibrary(
            'dart:core',
            serviceManager.service!,
          );

          final instance = (await eval.asyncEval('42', isAlive: isAlive))!;
          expect(instance.valueAsString, '42');

          final instance2 =
              (await eval.asyncEval('Future.value(42)', isAlive: isAlive))!;
          expect(instance2.classRef!.name, '_Future');
        },
        timeout: const Timeout.factor(8),
      );

      test(
        'returns the result of the future completion',
        () async {
          final mainIsolate = serviceManager.isolateManager.mainIsolate;
          expect(mainIsolate, isNotNull);

          final eval = EvalOnDartLibrary(
            'dart:core',
            serviceManager.service!,
            isolate: mainIsolate,
          );

          final instance = (await eval.asyncEval(
            // The delay asserts that there is no issue with garbage collection
            'await Future<int>.delayed(const Duration(milliseconds: 500), () => 42)',
            isAlive: isAlive,
          ))!;

          expect(instance.valueAsString, '42');
        },
        timeout: const Timeout.factor(8),
      );

      test(
        'throws FutureFailedException when the future is rejected',
        () async {
          final eval = EvalOnDartLibrary(
            'dart:core',
            serviceManager.service!,
          );

          final instance = await eval
              .asyncEval(
                'await Future.error(StateError("foo"), StackTrace.current)',
                isAlive: isAlive,
              )
              .then<FutureFailedException>(
                (_) => throw Exception(
                  'The FutureFailedException was not thrown as expected.',
                ),
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
              'stack': instance.stacktraceRef.id!,
            },
          );
          expect(
            stack.valueAsString,
            startsWith('#0      Eval.<anonymous closure> ()'),
          );

          final error = await eval.safeEval(
            'error.message',
            isAlive: isAlive,
            scope: {'error': instance.errorRef.id!},
          );
          expect(error.valueAsString, 'foo');
        },
        timeout: const Timeout.factor(8),
      );
    });
  });
}

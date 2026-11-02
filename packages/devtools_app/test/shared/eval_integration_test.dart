// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_driver.dart';
import '../test_infra/flutter_test_environment.dart';

void main() {
  final env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
    useTempDirectory: true,
  );

  late Disposable isAlive;

  setUp(() {
    isAlive = Disposable();
  });

  tearDown(() {
    isAlive.dispose();
  });

  tearDownAll(() async {
    await env.tearDownEnvironment(force: true);
    env.finalTeardown();
  });

  group('EvalOnDartLibrary', () {
    test('getHashCode', () async {
      await env.setupEnvironment();
      final eval = EvalOnDartLibrary(
        'dart:core',
        serviceConnection.serviceManager.service!,
        serviceManager: serviceConnection.serviceManager,
      );

      final instance = await eval.safeEval('42', isAlive: isAlive);

      await expectLater(
        eval.getHashCode(instance, isAlive: isAlive),
        completion(anyOf(isPositive, 0)),
      );
    }, timeout: const Timeout.factor(2));

    group('asyncEval', () {
      test(
        'supports expressions that do not start with the await keyword',
        () async {
          await env.setupEnvironment();

          final eval = EvalOnDartLibrary(
            'dart:core',
            serviceConnection.serviceManager.service!,
            serviceManager: serviceConnection.serviceManager,
          );

          final instance = (await eval.asyncEval('42', isAlive: isAlive))!;
          expect(instance.valueAsString, '42');

          final instance2 = (await eval.asyncEval(
            'Future.value(42)',
            isAlive: isAlive,
          ))!;
          expect(instance2.classRef!.name, '_Future');
        },
        timeout: const Timeout.factor(2),
      );

      test('returns the result of the future completion', () async {
        await env.setupEnvironment();
        final mainIsolate =
            serviceConnection.serviceManager.isolateManager.mainIsolate;

        final eval = EvalOnDartLibrary(
          'dart:core',
          serviceConnection.serviceManager.service!,
          serviceManager: serviceConnection.serviceManager,
          isolate: mainIsolate,
        );

        final instance = (await eval.asyncEval(
          // The delay asserts that there is no issue with garbage collection
          'await Future<int>.delayed(const Duration(milliseconds: 500), () => 42)',
          isAlive: isAlive,
        ))!;

        expect(instance.valueAsString, '42');
      }, timeout: const Timeout.factor(2));

      test('survives garbage collection while the future is pending', () async {
        await env.setupEnvironment();
        final mainIsolate =
            serviceConnection.serviceManager.isolateManager.mainIsolate;

        final eval = EvalOnDartLibrary(
          'dart:core',
          serviceConnection.serviceManager.service!,
          serviceManager: serviceConnection.serviceManager,
          isolate: mainIsolate,
        );

        final evalFuture = eval.asyncEval(
          'await Future<int>.delayed(const Duration(milliseconds: 500), () => 42)',
          isAlive: isAlive,
        );

        // Force garbage collection in the target isolate while the future is pending.
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await serviceConnection.serviceManager.service!.getAllocationProfile(
            mainIsolate.value!.id!,
            gc: true,
          );
        }

        final instance = (await evalFuture)!;
        expect(instance.valueAsString, '42');
      }, timeout: const Timeout.factor(2));

      test(
        'throws FutureFailedException when the future is rejected',
        () async {
          await env.setupEnvironment();

          final eval = EvalOnDartLibrary(
            'dart:core',
            serviceConnection.serviceManager.service!,
            serviceManager: serviceConnection.serviceManager,
          );

          late final FutureFailedException instance;
          try {
            await eval.asyncEval(
              'await Future.error(StateError("foo"), StackTrace.current)',
              isAlive: isAlive,
            );
            throw Exception(
              'The FutureFailedException was not thrown as expected.',
            );
          } on FutureFailedException catch (e) {
            instance = e;
          }

          expect(
            instance.expression,
            'await Future.error(StateError("foo"), StackTrace.current)',
          );

          final stack = await eval.safeEval(
            'stack.toString()',
            isAlive: isAlive,
            scope: {'stack': instance.stacktraceRef.id!},
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
        timeout: const Timeout.factor(2),
      );
    });
  });
}

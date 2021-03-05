// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member, non_constant_identifier_names

import 'package:devtools_app/src/instance_viewer/instance_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devtools_app/src/eval_on_dart_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/riverpod/provider_list.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../support/flutter_test_environment.dart';

typedef CancelSubscriptionCallback = Future<void> Function();

Future<void> runRiverpodControllerTests(FlutterTestEnvironment env) async {
  group('runRiverpodControllerTests', () {
    EvalOnDartLibrary eval;
    IsAlive isAlive;

    setUp(() async {
      await env.setupEnvironment();
      await serviceManager.service.allFuturesCompleted;

      isAlive = IsAlive();
      eval = EvalOnDartLibrary(
        [
          'package:riverpod_app/main.dart',
          'package:riverpod_app/tester.dart',
        ],
        env.service,
      );
    });

    Future<CancelSubscriptionCallback> listenToProvider({
      @required InstanceRef containerRef,
      @required String provider,
      Map<String, String> scope,
    }) async {
      final subscriptionRef = await eval.safeEval(
        'container.listen($provider)',
        isAlive: isAlive,
        scope: {...scope, 'container': containerRef.id},
      );

      await eval.awaitEval('tester.pump()', isAlive: isAlive);

      return () async {
        await eval.safeEval(
          'sub.close()',
          isAlive: isAlive,
          scope: {'sub': subscriptionRef.id},
        );
        await eval.awaitEval('tester.pump()', isAlive: isAlive);
      };
    }

    tearDown(() async {
      isAlive.dispose();
      eval.dispose();
      await env.tearDownEnvironment(force: true);
    });

    test('listens to state updates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final providerIds =
          await container.listen(providerIdsProvider.last).read();

      expect(providerIds.length, 2);

      final counterStateSub = container.listen(
        rawInstanceProvider(InstancePath.fromRiverpodId(providerIds.last))
            .future,
      );

      await expectLater(
        counterStateSub.read(),
        completion(
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '0'),
        ),
      );

      await eval.awaitEval(
        'tester.tap(find.byKey(Key("increment"))).then((_) => tester.pump())',
        isAlive: isAlive,
      );

      await expectLater(
        counterStateSub.read(),
        completion(
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '1'),
        ),
      );
    }, timeout: const Timeout.factor(8));

    test('shows the provider name and their family parameter (if any)',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final family = await eval.safeEval(
        'Provider.family<int, int>((ref, id) => id * 2)',
        isAlive: isAlive,
      );
      final containerRef =
          await eval.safeEval('ProviderContainer()', isAlive: isAlive);

      await Future.wait([
        listenToProvider(
          containerRef: containerRef,
          provider: 'family(0)',
          scope: {'family': family.id},
        ),
        listenToProvider(
          containerRef: containerRef,
          provider: 'family(42)',
          scope: {'family': family.id},
        ),
      ]);

      final ids = await container.listen(providerIdsProvider.last).read();

      await expectLater(
        Future.wait([
          for (final id in ids)
            container.listen(providerNodeProvider(id).future).read(),
        ]),
        completion([
          isA<ProviderNode>()
              .having((e) => e.paramDisplayString, 'paramDisplayString', null)
              .having((e) => e.type, 'type', 'StateNotifierProvider<Counter>'),
          isA<ProviderNode>()
              .having((e) => e.paramDisplayString, 'paramDisplayString', null)
              .having((e) => e.type, 'type', 'StateNotifierStateProvider<int>'),
          isA<ProviderNode>()
              .having((e) => e.paramDisplayString, 'paramDisplayString', '0')
              .having((e) => e.type, 'type', 'Provider<int>'),
          isA<ProviderNode>()
              .having((e) => e.paramDisplayString, 'paramDisplayString', '42')
              .having((e) => e.type, 'type', 'Provider<int>'),
        ]),
      );
    }, timeout: const Timeout.factor(8));

    test('list of provider updates when providers are added/removed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final providerIds = container.listen(providerIdsProvider.last);

      await expectLater(
        providerIds.read(),
        completion(hasLength(2)),
      );

      final provider = await eval.safeEval(
        'Provider.autoDispose((ref) => 42)',
        isAlive: isAlive,
      );
      final containerRef =
          await eval.safeEval('ProviderContainer()', isAlive: isAlive);

      final cancel = await listenToProvider(
        containerRef: containerRef,
        provider: 'provider',
        scope: {'provider': provider.id},
      );

      await expectLater(
        providerIds.read(),
        completion(hasLength(3)),
      );

      await cancel();

      await expectLater(
        providerIds.read(),
        completion(hasLength(2)),
      );
    }, timeout: const Timeout.factor(8));
  });
}

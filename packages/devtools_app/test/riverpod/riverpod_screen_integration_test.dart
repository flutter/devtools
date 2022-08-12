// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/riverpod/container_list.dart';
import 'package:devtools_app/src/shared/eval_on_dart_library.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import '../test_infra/flutter_test_driver.dart';
import '../test_infra/flutter_test_environment.dart';
import 'riverpod_test_helpers.dart';

void main() async {
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
    testAppDirectory: 'test/fixtures/riverpod_app',
  );

  late EvalOnDartLibrary evalOnDartLibrary;
  late Disposable isAlive;

  setUp(() async {
    setGlobal(IdeTheme, getIdeTheme());
    await env.setupEnvironment(
      config: const FlutterRunConfiguration(withDebugger: true),
    );
    await serviceManager.service!.allFuturesCompleted;

    isAlive = Disposable();
    evalOnDartLibrary = EvalOnDartLibrary(
      'package:riverpod_app/main.dart',
      env.service,
    );
  });

  tearDown(() async {
    isAlive.dispose();
    evalOnDartLibrary.dispose();
    await env.tearDownEnvironment(force: true);
  });

  Future<void> tapIncrement() {
    return evalOnDartLibrary.asyncEval(
      'await tester.tap(find.byKey(Key("increment"))).then((_) => tester.pump())',
      isAlive: isAlive,
    );
  }

  test(
    'should load containerNodesProvider with providers sorted by name',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(
        containerNodesProvider.future,
        (prev, next) {},
      );

      await tapIncrement();

      await expectLater(
        sub.read(),
        completion([
          matchContainerNode(
            id: '0',
            providers: [
              matchRiverpodNode(
                id: '0',
                containerId: '0',
                title:
                    'counterProvider - StateNotifierProvider<Counter, int>()',
              ),
              matchRiverpodNode(
                id: '1',
                containerId: '0',
                title:
                    'counterProvider.notifier - _NotifierProvider<Counter, int>()',
              ),
            ],
          ),
        ]),
      );
    },
    timeout: const Timeout.factor(8),
  );

  test(
    'should return true for supportsDevToolProvider',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(
        supportsDevToolProvider.future,
        (prev, next) {},
      );

      await expectLater(sub.read(), completion(isTrue));
    },
    timeout: const Timeout.factor(8),
  );
}

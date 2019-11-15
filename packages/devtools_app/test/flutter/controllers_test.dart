// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools_app/src/flutter/controllers.dart';
import 'package:devtools_app/src/flutter/initializer.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';

void main() {
  group('Controllers provider', () {
    setUp(() async {
      await ensureInspectorDependencies();
      final serviceManager = FakeServiceManager(useFakeService: true);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      setGlobal(ServiceConnectionManager, serviceManager);
    });

    testWidgets('provides default data', (WidgetTester tester) async {
      print('running test');
      ProvidedControllers provider;
      await tester.pumpWidget(
        Controllers(
          child: Builder(
            builder: (context) {
              provider = Controllers.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(provider, isNotNull);
    });

    testWidgets('disposes old provider data.', (WidgetTester tester) async {
      final overridden1 = TestProvidedControllers();
      final overridden2 = TestProvidedControllers();
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden1,
          child: const SizedBox(),
        ),
      );
      expect(disposed[overridden1], isFalse);
      expect(disposed[overridden2], isFalse);
      // Don't dispose when passing the same provider.
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden1,
          child: const SizedBox(),
        ),
      );
      expect(disposed[overridden1], isFalse);
      expect(disposed[overridden2], isFalse);

      // Dispose when passing a new provider.
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden2,
          child: const SizedBox(),
        ),
      );
      expect(disposed[overridden1], isTrue);
      expect(disposed[overridden2], isFalse);

      // This is weird, but expected.
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden1,
          child: const SizedBox(),
        ),
      );
      expect(disposed[overridden1], isTrue);
      expect(disposed[overridden2], isTrue);
    });
  });
}

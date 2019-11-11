// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/flutter/initializer.dart';
import 'package:devtools_app/src/flutter/provider.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';

void main() {
  group('Provider', () {
    setUp(() async {
      await ensureInspectorDependencies();
      final serviceManager = FakeServiceManager(useFakeService: true);
      setGlobal(ServiceConnectionManager, serviceManager);
    });

    testWidgets('provides default data', (WidgetTester tester) async {
      print('running test');
      ProviderData provider;
      await tester.pumpWidget(
        Provider(
          child: Builder(
            builder: (context) {
              provider = Provider.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(provider, isNotNull);
    });

    testWidgets('disposes old provider data.', (WidgetTester tester) async {
      final overridden1 = TestProviderData();
      final overridden2 = TestProviderData();
      await tester.pumpWidget(
        Provider(overrideProviders: () => overridden1, child: const SizedBox()),
      );
      expect(disposed[overridden1], isFalse);
      expect(disposed[overridden2], isFalse);
      // Don't dispose when passing the same provider.
      await tester.pumpWidget(
        Provider(overrideProviders: () => overridden1, child: const SizedBox()),
      );
      expect(disposed[overridden1], isFalse);
      expect(disposed[overridden2], isFalse);

      // Dispose when passing a new provider.
      await tester.pumpWidget(
        Provider(overrideProviders: () => overridden2, child: const SizedBox()),
      );
      expect(disposed[overridden1], isTrue);
      expect(disposed[overridden2], isFalse);

      // This is weird, but expected.
      await tester.pumpWidget(
        Provider(overrideProviders: () => overridden1, child: const SizedBox()),
      );
      expect(disposed[overridden1], isTrue);
      expect(disposed[overridden2], isTrue);
    });
  });
}

class TestProviderData extends Fake implements ProviderData {
  TestProviderData() {
    disposed[this] = false;
  }
  @override
  void dispose() {
    disposed[this] = true;
  }
}

final disposed = <TestProviderData, bool>{};

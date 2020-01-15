// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools_app/src/flutter/controllers.dart';
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
      final overridden1 = _TestProvidedControllers();
      final overridden2 = _TestProvidedControllers();
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden1,
          child: const SizedBox(),
        ),
      );
      expect(_disposed[overridden1], isFalse);
      expect(_disposed[overridden2], isFalse);
      // Don't dispose when passing the same provider.
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden1,
          child: const SizedBox(),
        ),
      );
      expect(_disposed[overridden1], isFalse);
      expect(_disposed[overridden2], isFalse);

      // Dispose when passing a new provider.
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden2,
          child: const SizedBox(),
        ),
      );
      expect(_disposed[overridden1], isTrue);
      expect(_disposed[overridden2], isFalse);

      // This is weird, but expected.
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden1,
          child: const SizedBox(),
        ),
      );
      expect(_disposed[overridden1], isTrue);
      expect(_disposed[overridden2], isTrue);
    });
    testWidgets('disposes old data after listeners have a chance to un-listen',
        (WidgetTester tester) async {
      final overridden1 = _TestProvidedControllers();
      final overridden2 = _TestProvidedControllers();

      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden1,
          child: _TestDependent(),
        ),
      );

      final state =
          tester.state<_TestDependentState>(find.byType(_TestDependent));
      expect(state.notifications, 0);
      overridden1.notifier.notifyListeners();
      expect(state.notifications, 1);

      // Change dependencies and dispose of the old controller.
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => overridden2,
          child: _TestDependent(),
        ),
      );
      expect(_disposed[overridden1], isTrue);
      expect(_disposed[overridden2], isFalse);

      expect(overridden1.notifier.removedCallbacks, [state.callback]);
      expect(state.notifications, 1);
      overridden2.notifier.notifyListeners();
      expect(state.notifications, 2);
    });
  });
}

/// A [ProvidedControllers] implementation that knows when it has been disposed.
class _TestProvidedControllers extends Fake implements ProvidedControllers {
  _TestProvidedControllers() {
    _disposed[this] = false;
  }
  @override
  void dispose() {
    _disposed[this] = true;
  }

  final _TestChangeNotifier notifier = _TestChangeNotifier();
}

final _disposed = <_TestProvidedControllers, bool>{};

class _TestDependent extends StatefulWidget {
  @override
  _TestDependentState createState() => _TestDependentState();
}

class _TestDependentState extends State<_TestDependent> {
  int notifications = 0;
  _TestProvidedControllers controllers;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newControllers = Controllers.of(context) as _TestProvidedControllers;
    if (newControllers == controllers) return;
    controllers?.notifier?.removeListener(callback);
    newControllers?.notifier?.addListener(callback);
    controllers = newControllers;
  }

  void callback() {
    setState(() {
      notifications++;
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// A [ChangeNotifier] that records which listeners have been removed.
class _TestChangeNotifier extends ChangeNotifier {
  List<VoidCallback> removedCallbacks = [];

  @override
  void removeListener(VoidCallback listener) {
    removedCallbacks.add(listener);
    super.removeListener(listener);
  }
}

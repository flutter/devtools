// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/flutter/controllers.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
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

      // Dispose when passing yet another new provider.
      await tester.pumpWidget(
        Controllers.overridden(
          overrideProviders: () => _TestProvidedControllers(),
          child: const SizedBox(),
        ),
      );
      expect(_disposed[overridden1], isTrue);
      expect(_disposed[overridden2], isTrue);
    });

    testWidgets(
        'disposes old data after stateful listeners have a chance to un-listen',
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

    testWidgets(
      'disposes old data after ValueListenableBuilders have a chance to '
      'un-listen',
      (WidgetTester tester) async {
        final overridden1 = _TestProvidedControllers();
        final overridden2 = _TestProvidedControllers();

        const value1 = 'Value 1';
        const value2 = 'Value 2';
        const valueEmpty = '';
        overridden1.notifier.value = value1;
        overridden2.notifier.value = valueEmpty;

        Widget build(BuildContext context) {
          final notifier =
              (Controllers.of(context) as _TestProvidedControllers).notifier;
          return ValueListenableBuilder<String>(
            valueListenable: notifier,
            builder: (context, value, __) => Directionality(
              textDirection: TextDirection.ltr,
              child: Text(value),
            ),
          );
        }

        await tester.pumpWidget(
          Controllers.overridden(
            overrideProviders: () => overridden1,
            child: Builder(builder: build),
          ),
        );

        expect(find.text(value1), findsOneWidget);
        expect(find.text(value2), findsNothing);
        expect(find.text(valueEmpty), findsNothing);
        overridden1.notifier.value = value2;
        await tester.pumpAndSettle();
        expect(find.text(value1), findsNothing);
        expect(find.text(value2), findsOneWidget);
        expect(find.text(valueEmpty), findsNothing);

        // Change dependencies and dispose of the old controller.
        await tester.pumpWidget(
          Controllers.overridden(
            overrideProviders: () => overridden2,
            child: Builder(builder: build),
          ),
        );
        expect(_disposed[overridden1], isTrue);
        expect(_disposed[overridden2], isFalse);

        expect(overridden1.notifier.removedCallbacks, hasLength(1));
        expect(find.text(valueEmpty), findsOneWidget);
        expect(find.text(value1), findsNothing);
        expect(find.text(value2), findsNothing);

        overridden2.notifier.value = value1;
        await tester.pumpAndSettle();
        expect(find.text(value1), findsOneWidget);
        expect(find.text(value2), findsNothing);
        expect(find.text(valueEmpty), findsNothing);
      },
    );
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
    notifier.dispose();
  }

  final _TestChangeNotifier notifier = _TestChangeNotifier('');
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
class _TestChangeNotifier extends ValueNotifier<String> {
  _TestChangeNotifier(value) : super(value);

  List<VoidCallback> removedCallbacks = [];

  @override
  void removeListener(VoidCallback listener) {
    removedCallbacks.add(listener);
    super.removeListener(listener);
  }
}

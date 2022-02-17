// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_app/src/provider/instance_viewer/instance_details.dart';
import 'package:devtools_app/src/provider/instance_viewer/instance_providers.dart';
import 'package:devtools_app/src/provider/provider_list.dart';
import 'package:devtools_app/src/provider/provider_nodes.dart';
import 'package:devtools_app/src/provider/provider_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
@TestOn('vm')
import 'package:devtools_app/src/shared/banner_messages.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  Widget providerScreen;
  BannerMessagesController bannerMessagesController;

  setUpAll(() => loadFonts());

  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
  });

  setUp(() {
    bannerMessagesController = BannerMessagesController();

    providerScreen = Container(
      color: Colors.grey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: wrapWithControllers(
          const BannerMessages(screen: ProviderScreen()),
          bannerMessages: bannerMessagesController,
        ),
      ),
    );
  });

  group('ProviderScreen', () {
    testWidgetsWithWindowSize(
        'shows ProviderUnknownErrorBanner if the devtool failed to fetch the list of providers',
        windowSize, (tester) async {
      final container = ProviderContainer(overrides: [
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.loading(),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: providerScreen,
        ),
      );

      container.updateOverrides([
        rawSortedProviderNodesProvider.overrideWithValue(
          AsyncValue.error(StateError('')),
        ),
      ]);

      // wait for the Banner to appear as it is mounted asynchronously
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ProviderScreenBody),
        matchesGoldenFile('../goldens/provider_screen/list_error_banner.png'),
      );
    });
  });

  group('selectedProviderIdProvider', () {
    test('selects the first provider available', () async {
      final container = ProviderContainer(overrides: [
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.loading(),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      expect(sub.read(), isNull);

      container.updateOverrides([
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '0', type: 'Provider<A>'),
            ProviderNode(id: '1', type: 'Provider<B>'),
          ]),
        ),
      ]);

      await container.pumpAndSettle();

      expect(sub.read(), '0');
    });

    test('selects the first provider available after an error', () async {
      final container = ProviderContainer(overrides: [
        rawSortedProviderNodesProvider.overrideWithValue(
          AsyncValue.error(Error()),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      // wait for the error to be handled
      await container.pumpAndSettle();

      expect(sub.read(), isNull);

      container.updateOverrides([
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '0', type: 'Provider<A>'),
            ProviderNode(id: '1', type: 'Provider<B>'),
          ]),
        ),
      ]);

      // wait for the ids update to be handled
      await container.pumpAndSettle(exclude: [selectedProviderIdProvider]);

      expect(sub.read(), '0');
    });

    test(
        'When the currently selected provider is removed, selects the next first provider',
        () async {
      final container = ProviderContainer(overrides: [
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '0', type: 'Provider<A>'),
          ]),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      await container.pumpAndSettle();

      expect(sub.read(), '0');

      container.updateOverrides([
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '1', type: 'Provider<B>'),
          ]),
        ),
      ]);

      await container.pumpAndSettle();

      expect(sub.read(), '1');
    });

    test('Once a provider is selected, further updates are no-op', () async {
      final container = ProviderContainer(overrides: [
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '0', type: 'Provider<A>'),
          ]),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      await container.pumpAndSettle();

      expect(sub.read(), '0');

      container.updateOverrides([
        rawSortedProviderNodesProvider.overrideWithValue(
          // '0' is no-longer the first provider on purpose
          const AsyncValue.data([
            ProviderNode(id: '1', type: 'Provider<B>'),
            ProviderNode(id: '0', type: 'Provider<A>'),
          ]),
        ),
      ]);

      await container.pumpAndSettle();

      expect(sub.read(), '0');
    });

    test(
        'when the list of providers becomes empty, the current provider is unselected '
        ', then, the first provider will be selected when the list becomes non-empty again.',
        () async {
      final container = ProviderContainer(overrides: [
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '0', type: 'Provider<A>'),
          ]),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      await container.pumpAndSettle();

      expect(sub.read(), '0');

      container.updateOverrides([
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([]),
        ),
      ]);

      await container.pumpAndSettle();

      expect(sub.read(), isNull);

      container.updateOverrides([
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '1', type: 'Provider<B>'),
          ]),
        ),
      ]);

      await container.pumpAndSettle();

      expect(sub.read(), '1');
    });
  });

  group('ProviderList', () {
    List<Override> getOverrides() {
      return [
        rawInstanceProvider(const InstancePath.fromProviderId('0'))
            .overrideWithValue(AsyncValue.data(
          InstanceDetails.string(
            'Value0',
            instanceRefId: 'string/0',
            setter: null,
          ),
        ))
      ];
    }

    testWidgetsWithWindowSize(
        'selects the first provider the first time a provider is received',
        windowSize, (tester) async {
      final container = ProviderContainer(overrides: [
        rawSortedProviderNodesProvider
            .overrideWithValue(const AsyncValue.loading()),
        ...getOverrides(),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: providerScreen,
        ),
      );

      final context = tester.element(find.byType(ProviderScreenBody));

      expect(context.read(selectedProviderIdProvider), isNull);
      expect(find.byType(ProviderNodeItem), findsNothing);

      await expectLater(
        find.byType(ProviderScreenBody),
        matchesGoldenFile(
            '../goldens/provider_screen/no_selected_provider.png'),
      );

      container.updateOverrides([
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '0', type: 'Provider<A>'),
            ProviderNode(id: '1', type: 'Provider<B>'),
          ]),
        ),
        ...getOverrides(),
      ]);

      await tester.pumpAndSettle();

      expect(context.read(selectedProviderIdProvider), '0');
      expect(find.byType(ProviderNodeItem), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byKey(const Key('provider-0')),
          matching: find.text('Provider<A>()'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('provider-1')),
          matching: find.text('Provider<B>()'),
        ),
        findsOneWidget,
      );

      await expectLater(
        find.byType(ProviderScreenBody),
        matchesGoldenFile('../goldens/provider_screen/selected_provider.png'),
      );
    });

    testWidgetsWithWindowSize(
        'shows ProviderUnknownErrorBanner if the devtool failed to fetch the selected provider',
        windowSize, (tester) async {
      final overrides = [
        rawSortedProviderNodesProvider.overrideWithValue(
          const AsyncValue.data([
            ProviderNode(id: '0', type: 'Provider<A>'),
            ProviderNode(id: '1', type: 'Provider<B>'),
          ]),
        ),
        ...getOverrides(),
      ];

      final container = ProviderContainer(
        overrides: [
          ...overrides,
          rawInstanceProvider(const InstancePath.fromProviderId('0'))
              .overrideWithValue(const AsyncValue.loading())
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: providerScreen,
        ),
      );

      container.updateOverrides([
        ...overrides,
        rawInstanceProvider(const InstancePath.fromProviderId('0'))
            .overrideWithValue(AsyncValue.error(Error()))
      ]);

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('ProviderUnknownErrorBanner - ${ProviderScreen.id}'),
        ),
        findsOneWidget,
      );

      await expectLater(
        find.byType(ProviderScreenBody),
        matchesGoldenFile(
            '../goldens/provider_screen/selected_provider_error_banner.png'),
      );
    });
  });
}

extension on ProviderContainer {
  // TODO(rrousselGit) remove this utility when riverpod v0.15.0 is released
  Future<void> pumpAndSettle({
    List<ProviderBase> exclude = const [],
  }) async {
    bool hasDirtyProvider() {
      return debugProviderElements
          // ignore: invalid_use_of_protected_member
          .any((e) => e.dirty && !exclude.contains(e.provider));
    }

    while (hasDirtyProvider()) {
      for (final element in debugProviderElements) {
        element.flush();
      }
      await Future(() {});
    }
  }
}

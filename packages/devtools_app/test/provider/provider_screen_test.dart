// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/banner_messages.dart';
import 'package:devtools_app/src/instance_viewer/instance_providers.dart';
import 'package:devtools_app/src/provider/provider_list.dart';
@TestOn('vm')
import 'package:devtools_app/src/provider/provider_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedantic/pedantic.dart';

import '../support/utils.dart';
import '../support/wrappers.dart';

void main() {
  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  Widget providerScreen;
  BannerMessagesController bannerMessagesController;

  setUpAll(() => loadFonts());

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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerIdsProvider.overrideWithProvider(
              StreamProvider.autoDispose((ref) => Stream.error(StateError(''))),
            )
          ],
          child: providerScreen,
        ),
      );

      // wait for the Stream.error to be emitted
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
        providerIdsProvider.overrideWithValue(
          const AsyncValue.loading(),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      expect(sub.read().state, isNull);

      container.updateOverrides([
        providerIdsProvider.overrideWithValue(
          const AsyncValue.data(['0', '1']),
        ),
      ]);

      // wait for the event loop to complete once
      await Future.value();

      expect(sub.read().state, '0');
    });

    test('selects the first provider available after an error', () async {
      final container = ProviderContainer(overrides: [
        providerIdsProvider.overrideWithValue(
          AsyncValue.error(Error()),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      // wait for the error to be handled
      await Future.value();

      expect(sub.read().state, isNull);

      container.updateOverrides([
        providerIdsProvider.overrideWithValue(
          const AsyncValue.data(['0', '1']),
        ),
      ]);

      // wait for the ids update to be handled
      await Future.value();

      expect(sub.read().state, '0');
    });

    test(
        'When the currently selected provider is removed, selects the next first provider',
        () async {
      final container = ProviderContainer(overrides: [
        providerIdsProvider.overrideWithValue(
          const AsyncValue.data(['0']),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      // wait for the first provider to be selected
      await Future.value();

      expect(sub.read().state, '0');

      container.updateOverrides([
        providerIdsProvider.overrideWithValue(
          const AsyncValue.data(['1']),
        ),
      ]);

      // wait for the update to be handled
      await Future.value();

      expect(sub.read().state, '1');
    });

    test('Once a provider is selected, further updates are no-op', () async {
      final container = ProviderContainer(overrides: [
        providerIdsProvider.overrideWithValue(
          const AsyncValue.data(['0']),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      // wait for the first provider to be selected
      await Future.value();

      expect(sub.read().state, '0');

      container.updateOverrides([
        providerIdsProvider.overrideWithValue(
          // '0' is no-longer the first provider on purpose
          const AsyncValue.data(['1', '0']),
        ),
      ]);

      // wait for the update to be handled
      await Future.value();

      expect(sub.read().state, '0');
    });

    test(
        'when the list of providers becomes empty, the current provider is unselected '
        ', then, the first provider will be selected when the list becomes non-empty again.',
        () async {
      final container = ProviderContainer(overrides: [
        providerIdsProvider.overrideWithValue(
          const AsyncValue.data(['0']),
        ),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(selectedProviderIdProvider);

      // wait for the first provider to be selected
      await Future.value();

      expect(sub.read().state, '0');

      container.updateOverrides([
        providerIdsProvider.overrideWithValue(
          const AsyncValue.data([]),
        ),
      ]);

      // wait for the ids update to be handled
      await Future.value();

      expect(sub.read().state, isNull);

      container.updateOverrides([
        providerIdsProvider.overrideWithValue(
          const AsyncValue.data(['1']),
        ),
      ]);

      // wait for the ids update to be handled
      await Future.value();

      expect(sub.read().state, '1');
    });
  });

  group('ProviderList', () {
    List<Override> getOverrides() {
      return [
        providerNodeProvider('0').overrideWithValue(
          const AsyncValue.data(
            ProviderNode(id: '0', type: 'Provider0'),
          ),
        ),
        providerNodeProvider('1').overrideWithValue(
          const AsyncValue.data(
            ProviderNode(id: '1', type: 'ChangeNotifierProvider1'),
          ),
        ),
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerIdsProvider.overrideWithValue(const AsyncValue.loading()),
            ...getOverrides(),
          ],
          child: providerScreen,
        ),
      );

      final context = tester.element(find.byType(ProviderScreenBody));

      expect(context.read(selectedProviderIdProvider).state, isNull);
      expect(find.byType(ProviderNodeItem), findsNothing);

      await expectLater(
        find.byType(ProviderScreenBody),
        matchesGoldenFile(
            '../goldens/provider_screen/no_selected_provider.png'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerIdsProvider.overrideWithValue(
              const AsyncValue.data(['0', '1']),
            ),
            ...getOverrides(),
          ],
          child: providerScreen,
        ),
      );

      // wait for selectedProviderIdProvider to select the first provider
      await tester.pumpAndSettle();

      expect(context.read(selectedProviderIdProvider).state, '0');
      expect(find.byType(ProviderNodeItem), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byKey(const Key('provider-0')),
          matching: find.text('Provider0()'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('provider-1')),
          matching: find.text('ChangeNotifierProvider1()'),
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
      final container = ProviderContainer(
        overrides: [
          providerIdsProvider.overrideWithValue(
            const AsyncValue.data(['0', '1']),
          ),
          ...getOverrides(),
          rawInstanceProvider(const InstancePath.fromProviderId('0'))
              .overrideWithValue(AsyncValue.error(Error()))
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: providerScreen,
        ),
      );

      // wait for the Stream.error to be emitted
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ProviderScreenBody),
        matchesGoldenFile(
            '../goldens/provider_screen/selected_provider_error_banner.png'),
      );
    });
  });
}

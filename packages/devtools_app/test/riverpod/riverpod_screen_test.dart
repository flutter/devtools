// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/provider/instance_viewer/instance_details.dart';
import 'package:devtools_app/src/screens/provider/instance_viewer/instance_providers.dart';
import 'package:devtools_app/src/screens/provider/instance_viewer/instance_viewer.dart';
import 'package:devtools_app/src/screens/riverpod/container_list.dart';
import 'package:devtools_app/src/screens/riverpod/nodes/container_node.dart';
import 'package:devtools_app/src/screens/riverpod/nodes/riverpod_node.dart';
import 'package:devtools_app/src/screens/riverpod/refresh_state_button.dart';
import 'package:devtools_app/src/screens/riverpod/riverpod_screen.dart';
import 'package:devtools_app/src/screens/riverpod/selected_provider.dart';
import 'package:devtools_app/src/screens/riverpod/settings_dialog_button.dart';
import 'package:devtools_app/src/service/service_manager.dart';
@TestOn('vm')
import 'package:devtools_app/src/shared/banner_messages.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class RefreshNotifierMock extends Mock implements RefreshNotifier {}

void main() {
  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  late Widget riverpodScreen;
  late BannerMessagesController bannerMessagesController;

  setUpAll(() => loadFonts());

  setUp(() {
    setGlobal(IdeTheme, getIdeTheme());
    setGlobal(ServiceConnectionManager, FakeServiceManager());
  });

  setUp(() {
    bannerMessagesController = BannerMessagesController();

    riverpodScreen = Container(
      color: Colors.grey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: wrapWithControllers(
          const BannerMessages(screen: RiverpodScreen()),
          bannerMessages: bannerMessagesController,
        ),
      ),
    );
  });

  group('ProviderScreen', () {
    testWidgetsWithWindowSize(
      'shows multiple containers',
      windowSize,
      (tester) async {
        final provider0 = RiverpodNode(
          id: '0',
          containerId: '0',
          stateId: 'stateId',
          type: 'String',
          name: 'provider0',
          mightBeOutdated: false,
        );
        final provider1 = RiverpodNode(
          id: '1',
          containerId: '1',
          stateId: 'stateId',
          type: 'String',
          name: 'provider1',
          mightBeOutdated: false,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(true),
              ),
              containerNodesProvider.overrideWithValue(
                AsyncValue.data([
                  ContainerNode(
                    id: '0',
                    providers: [provider0],
                  ),
                  ContainerNode(
                    id: '1',
                    providers: [provider1],
                  ),
                ]),
              ),
            ],
            child: riverpodScreen,
          ),
        );

        await expectLater(
          find.text('Container #0'),
          findsOneWidget,
        );
        await expectLater(
          find.text('Container #1'),
          findsOneWidget,
        );
        await expectLater(
          find.text(provider0.title),
          findsOneWidget,
        );
        await expectLater(
          find.text(provider1.title),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'shows alert when provider might be outdated',
      windowSize,
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(true),
              ),
              containerNodesProvider.overrideWithValue(
                AsyncValue.data([
                  ContainerNode(
                    id: '0',
                    providers: [
                      RiverpodNode(
                        id: '0',
                        containerId: '0',
                        stateId: 'stateId',
                        type: 'String',
                        name: 'provider0',
                        mightBeOutdated: true,
                      )
                    ],
                  ),
                ]),
              ),
            ],
            child: riverpodScreen,
          ),
        );

        await expectLater(
          find.byIcon(Icons.warning),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'shows _UnsupportedMessage if supportsDevToolProvider returns false',
      windowSize,
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(false),
              )
            ],
            child: riverpodScreen,
          ),
        );

        await expectLater(
          find.byKey(const Key('riverpod-unsupported-message')),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'shows _UnsupportedMessage if supportsDevToolProvider throws error',
      windowSize,
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.error('fake_error'),
              )
            ],
            child: riverpodScreen,
          ),
        );

        await expectLater(
          find.byKey(const Key('riverpod-unsupported-message')),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'shows ContainerList if supportsDevToolProvider returns true',
      windowSize,
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(true),
              )
            ],
            child: riverpodScreen,
          ),
        );

        await expectLater(
          find.byType(ContainerList),
          findsOneWidget,
        );
      },
    );
  });

  group('selected provider', () {
    testWidgetsWithWindowSize(
      'shows no provider selected message when there is no provider selected',
      windowSize,
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(true),
              )
            ],
            child: riverpodScreen,
          ),
        );

        await expectLater(
          find.text('[No provider selected]'),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'shows no provider selected message when there is no provider selected',
      windowSize,
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(true),
              )
            ],
            child: riverpodScreen,
          ),
        );

        await expectLater(
          find.text('[No provider selected]'),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'shows selected provider value',
      windowSize,
      (tester) async {
        const instanceId = 'fake_state';
        const state = 'this is a fake value';
        final provider = RiverpodNode(
          id: '0',
          containerId: '0',
          stateId: instanceId,
          type: 'String',
          name: 'firstProvider',
          mightBeOutdated: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(true),
              ),
              containerNodesProvider.overrideWithValue(
                AsyncValue.data([
                  ContainerNode(id: '0', providers: [provider])
                ]),
              ),
              selectedNodeProvider.overrideWithValue(provider),
              instanceProvider(
                const InstancePath.fromInstanceId(instanceId),
              ).overrideWithValue(
                AsyncValue.data(
                  InstanceDetails.string(
                    state,
                    instanceRefId: instanceId,
                    setter: null,
                  ),
                ),
              )
            ],
            child: riverpodScreen,
          ),
        );

        await expectLater(
          find.text(provider.title),
          findsNWidgets(2),
        );
        await expectLater(
          find.byType(InstanceViewer),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'refresh tap should call refresh',
      windowSize,
      (tester) async {
        const instanceId = 'fake_state';
        const state = 'this is a fake value';
        final refreshNotifier = RefreshNotifierMock();
        final provider = RiverpodNode(
          id: '0',
          containerId: '0',
          stateId: instanceId,
          type: 'String',
          name: 'firstProvider',
          mightBeOutdated: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              refreshNotifierProvider.overrideWithValue(refreshNotifier),
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(true),
              ),
              containerNodesProvider.overrideWithValue(
                AsyncValue.data([
                  ContainerNode(id: '0', providers: [provider])
                ]),
              ),
              selectedNodeProvider.overrideWithValue(provider),
              instanceProvider(
                const InstancePath.fromInstanceId(instanceId),
              ).overrideWithValue(
                AsyncValue.data(
                  InstanceDetails.string(
                    state,
                    instanceRefId: instanceId,
                    setter: null,
                  ),
                ),
              )
            ],
            child: riverpodScreen,
          ),
        );

        await tester.tap(find.byType(RefreshStateButton));

        verify(refreshNotifier.refresh()).called(1);
      },
    );

    testWidgetsWithWindowSize(
      'settings tap should show settings dialog',
      windowSize,
      (tester) async {
        const instanceId = 'fake_state';
        const state = 'this is a fake value';
        final refreshNotifier = RefreshNotifierMock();
        final provider = RiverpodNode(
          id: '0',
          containerId: '0',
          stateId: instanceId,
          type: 'String',
          name: 'firstProvider',
          mightBeOutdated: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              refreshNotifierProvider.overrideWithValue(refreshNotifier),
              supportsDevToolProvider.overrideWithValue(
                const AsyncValue.data(true),
              ),
              containerNodesProvider.overrideWithValue(
                AsyncValue.data([
                  ContainerNode(id: '0', providers: [provider])
                ]),
              ),
              selectedNodeProvider.overrideWithValue(provider),
              instanceProvider(
                const InstancePath.fromInstanceId(instanceId),
              ).overrideWithValue(
                AsyncValue.data(
                  InstanceDetails.string(
                    state,
                    instanceRefId: instanceId,
                    setter: null,
                  ),
                ),
              )
            ],
            child: riverpodScreen,
          ),
        );

        await tester.tap(find.byType(SettingsDialogButton));
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const Key('state-inspector-settings-dialog')),
          findsOneWidget,
        );
      },
    );
  });

  group('refreshProvider', () {
    test('should refresh selected provider', () async {
      const firstStateId = 'fake/1';
      const secondStateId = 'fake/1';
      final provider = RiverpodNode(
        id: '0',
        containerId: '0',
        stateId: firstStateId,
        type: 'String',
        name: 'provider0',
        mightBeOutdated: false,
      );
      final updatedProvider = provider.copy(stateId: secondStateId);

      final container = ProviderContainer(
        overrides: [
          containerNodesProvider.overrideWithValue(
            AsyncValue.data([
              ContainerNode(
                id: '0',
                providers: [provider],
              ),
            ]),
          ),
          updatedRiverpodNodeProvider(provider).overrideWithValue(
            AsyncValue.data(provider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final selectedNodeSub = container.listen<RiverpodNode?>(
        selectedNodeProvider,
        (prev, next) {},
      );

      expect(selectedNodeSub.read(), isNull);

      container.read(selectedNodeStateProvider.notifier).state = provider;
      await container.pump();

      expect(selectedNodeSub.read(), equals(provider));

      container.updateOverrides([
        containerNodesProvider.overrideWithValue(
          AsyncValue.data([
            ContainerNode(
              id: '0',
              providers: [updatedProvider],
            ),
          ]),
        ),
        updatedRiverpodNodeProvider(provider).overrideWithValue(
          AsyncValue.data(updatedProvider),
        ),
      ]);
      container.read(refreshNotifierProvider).refresh();
      await container.pump();

      expect(selectedNodeSub.read(), equals(updatedProvider));
    });
  });
}

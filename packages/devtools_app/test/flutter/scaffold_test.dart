// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/banner_messages.dart';
import 'package:devtools_app/src/flutter/scaffold.dart';
import 'package:devtools_app/src/flutter/screen.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  group('DevToolsScaffold widget', () {
    MockServiceManager mockServiceManager;

    setUp(() {
      mockServiceManager = MockServiceManager();
      when(mockServiceManager.service).thenReturn(null);
      setGlobal(ServiceConnectionManager, mockServiceManager);
    });

    testWidgetsWithWindowSize(
        'displays in narrow mode without error', const Size(800.0, 1200.0),
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const DevToolsScaffold(
          tabs: [screen1, screen2, screen3, screen4, screen5],
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.fullWidthKey), findsNothing);
    });

    testWidgetsWithWindowSize(
        'displays in full-width mode without error', const Size(1203.0, 1200.0),
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const DevToolsScaffold(
          tabs: [screen1, screen2, screen3, screen4, screen5],
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.fullWidthKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsNothing);
    });

    testWidgets('displays no tabs when only one is given',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const DevToolsScaffold(tabs: [screen1]),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(t1), findsNothing);
    });

    testWidgets('displays only the selected tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const DevToolsScaffold(
          tabs: [screen1, screen2],
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(k2), findsNothing);

      // Tap on the tab for screen 2, then let the animation finish before
      // checking the body is updated.
      await tester.tap(find.byKey(t2));
      await tester.pumpAndSettle();
      expect(find.byKey(k1), findsNothing);
      expect(find.byKey(k2), findsOneWidget);

      // Return to screen 1.
      await tester.tap(find.byKey(t1));
      await tester.pumpAndSettle();
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(k2), findsNothing);
    });

    testWidgets('displays proper messages for screen',
        (WidgetTester tester) async {
      final bannerMessagesController = MockBannerMessagesController();
      when(bannerMessagesController.onRefreshMessages)
          .thenAnswer((_) => const Stream.empty());
      when(bannerMessagesController.isMessageDismissed(any)).thenReturn(false);
      await tester.pumpWidget(wrapWithControllers(
        const DevToolsScaffold(
          tabs: [screen1, screen3, screen4],
        ),
        bannerMessages: bannerMessagesController,
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byType(BannerMessageContainer), findsOneWidget);
      expect(find.byKey(message1Key), findsNothing);
      expect(find.byKey(message2Key), findsNothing);

      await tester.tap(find.byKey(t3));
      await tester.pumpAndSettle();
      expect(find.byKey(k1), findsNothing);
      expect(find.byKey(k3), findsOneWidget);
      expect(find.byType(BannerMessageContainer), findsOneWidget);
      expect(find.byKey(message1Key), findsOneWidget);
      expect(find.byKey(message2Key), findsNothing);

      await tester.tap(find.byKey(t4));
      await tester.pumpAndSettle();
      expect(find.byKey(k3), findsNothing);
      expect(find.byKey(k4), findsOneWidget);
      expect(find.byType(BannerMessageContainer), findsOneWidget);
      expect(find.byKey(message1Key), findsNothing);
      expect(find.byKey(message2Key), findsOneWidget);
    });
  });
}

class _TestScreen extends Screen {
  const _TestScreen(
    this.name,
    this.key, {
    this.messageList = const [],
    Key tabKey,
  }) : super(
          DevToolsScreenType.simple,
          title: name,
          icon: Icons.computer,
          tabKey: tabKey,
        );

  final String name;
  final Key key;
  final List<Widget> messageList;

  @override
  List<Widget> messages(BuildContext context) {
    return messageList;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: key);
  }
}

class _TestMessage extends StatelessWidget implements UniqueMessage {
  const _TestMessage(this.messageId, {@required Key key}) : super(key: key);

  final String messageId;

  @override
  String get id => messageId;

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

// Keys and tabs for use in the test.
const k1 = Key('body key 1');
const k2 = Key('body key 2');
const k3 = Key('body key 3');
const k4 = Key('body key 4');
const k5 = Key('body key 5');
const t1 = Key('tab key 1');
const t2 = Key('tab key 2');
const t3 = Key('tab key 3');
const t4 = Key('tab key 4');
const message1Key = Key('test message 1');
const message2Key = Key('test message 2');
const message1 = _TestMessage('test message 1', key: message1Key);
const message2 = _TestMessage('test message 2', key: message2Key);
const screen1 = _TestScreen('screen1', k1, tabKey: t1);
const screen2 = _TestScreen('screen2', k2, tabKey: t2);
const screen3 = _TestScreen('screen3', k3, tabKey: t3, messageList: [message1]);
const screen4 = _TestScreen('screen4', k4, tabKey: t4, messageList: [message2]);
const screen5 = _TestScreen('screen5', k5);

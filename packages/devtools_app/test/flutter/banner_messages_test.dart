// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/banner_messages.dart';
import 'package:devtools_app/src/flutter/common_widgets.dart';
import 'package:devtools_app/src/flutter/screen.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  BannerMessagesController controller;
  FakeServiceManager fakeServiceManager;

  setUp(() {
    controller = BannerMessagesController();
    fakeServiceManager = FakeServiceManager(useFakeService: true);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
  });

  group('BannerMessagesController', () {
    test('removeMessage removes and dismisses correctly', () {
      expect(controller.isMessageDismissed(testMessage1), isFalse);
      controller.removeMessage(testMessage1);
      expect(controller.isMessageDismissed(testMessage1), isFalse);
      controller.removeMessage(testMessage1, dismiss: true);
      expect(controller.isMessageDismissed(testMessage1), isTrue);
    });

    test('removeMessageByKey removes correct message', () {
      controller.addMessage(testMessage1);
      controller.addMessage(testMessage2);
      expect(controller.messagesForScreen(testMessage1ScreenType).value,
          contains(testMessage1));
      expect(controller.messagesForScreen(testMessage1ScreenType).value,
          contains(testMessage2));
      controller.removeMessageByKey(k1, testMessage1ScreenType);
      expect(controller.messagesForScreen(testMessage1ScreenType).value,
          isNot(contains(testMessage1)));
      expect(controller.messagesForScreen(testMessage1ScreenType).value,
          contains(testMessage2));
    });

    test('addMessage adds messages', () {
      expect(controller.isMessageVisible(testMessage1), isFalse);
      controller.addMessage(testMessage1);
      expect(controller.isMessageVisible(testMessage1), isTrue);
    });

    test('addMessage does not add duplicate messages', () {
      expect(controller.isMessageVisible(testMessage1), isFalse);
      controller.addMessage(testMessage1);
      expect(controller.isMessageVisible(testMessage1), isTrue);
      expect(controller.messagesForScreen(testMessage1ScreenType).value.length,
          equals(1));
      controller.addMessage(testMessage1);
      expect(controller.messagesForScreen(testMessage1ScreenType).value.length,
          equals(1));
    });

    test('messagesForScreen returns correct messages', () {
      expect(
          controller.messagesForScreen(testMessage1ScreenType).value, isEmpty);
      expect(
          controller.messagesForScreen(testMessage3ScreenType).value, isEmpty);
      controller.addMessage(testMessage1);
      controller.addMessage(testMessage3);
      expect(controller.messagesForScreen(testMessage1ScreenType).value,
          contains(testMessage1));
      expect(controller.messagesForScreen(testMessage3ScreenType).value,
          contains(testMessage3));
    });
  });

  group('BannerMessages', () {
    BuildContext buildContext;

    /// Pumps a test frame so that we can ensure post frame callbacks are
    /// executed.
    Future<void> pumpTestFrame(WidgetTester tester) async {
      // Tap the raised Button in order to draw a frame.
      await tester.tap(find.byType(RaisedButton));
      await tester.pumpAndSettle();
    }

    Widget buildBannerMessages() {
      return wrapWithControllers(
        Directionality(
          textDirection: TextDirection.ltr,
          child: wrapWithBannerMessages(
            Builder(
              builder: (context) {
                buildContext = context;
                return Column(
                  children: <Widget>[
                    // This is button is present so that we can tap it and
                    // simulate a frame being drawn.
                    RaisedButton(
                      onPressed: () => {},
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        bannerMessages: controller,
      );
    }

    testWidgets('displays banner messages', (WidgetTester tester) async {
      final bannerMessages = buildBannerMessages();
      await tester.pumpWidget(bannerMessages);
      expect(find.byKey(k1), findsNothing);
      BannerMessages.of(buildContext).push(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      expect(find.byKey(k2), findsNothing);
      BannerMessages.of(buildContext).push(testMessage2);
      await pumpTestFrame(tester);
      expect(find.byKey(k2), findsOneWidget);
    });

    testWidgets('removes and dismisses messages', (WidgetTester tester) async {
      final bannerMessages = buildBannerMessages();
      await tester.pumpWidget(bannerMessages);
      expect(find.byKey(k1), findsNothing);
      BannerMessages.of(buildContext).push(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      BannerMessages.of(buildContext).remove(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message can be re-added, since it was not removed with
      // `dismiss = true`.
      BannerMessages.of(buildContext).push(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      BannerMessages.of(buildContext).remove(testMessage1, dismiss: true);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message cannot be re-added, since it was removed with
      // `dismiss = true`.
      BannerMessages.of(buildContext).push(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);
    });

    testWidgets('messages self dismiss', (WidgetTester tester) async {
      final bannerMessages = buildBannerMessages();
      await tester.pumpWidget(bannerMessages);
      expect(find.byKey(k1), findsNothing);
      BannerMessages.of(buildContext).push(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      await tester.tap(find.byType(CircularIconButton));
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message cannot be re-added, since it was removed with
      // `dismiss = true`.
      BannerMessages.of(buildContext).push(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);
    });
  });
}

// These screen types are arbitrary.
const testMessage1ScreenType = DevToolsScreenType.simple;
const testMessage2ScreenType = DevToolsScreenType.simple;
const testMessage3ScreenType = DevToolsScreenType.performance;
const k1 = Key('test message 1');
const k2 = Key('test message 2');
const k3 = Key('test message 3');
const testMessage1 = BannerMessage(
  key: k1,
  textSpans: [TextSpan(text: 'Test Message 1')],
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  screenType: testMessage1ScreenType,
);
const testMessage2 = BannerMessage(
  key: k2,
  textSpans: [TextSpan(text: 'Test Message 2')],
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  screenType: testMessage2ScreenType,
);
const testMessage3 = BannerMessage(
  key: k3,
  textSpans: [TextSpan(text: 'Test Message 3')],
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  screenType: testMessage3ScreenType,
);

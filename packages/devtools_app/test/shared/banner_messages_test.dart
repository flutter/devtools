// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/framework/scaffold.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/banner_messages.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;

  setUp(() {
    fakeServiceConnection = FakeServiceConnectionManager();
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
  });

  group('BannerMessages', () {
    /// Pumps a test frame so that we can ensure post frame callbacks are
    /// executed.
    Future<void> pumpTestFrame(WidgetTester tester) async {
      // Tap the raised Button in order to draw a frame.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
    }

    Widget buildBannerMessages() {
      return wrap(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BannerMessages(
            screen: SimpleScreen(
              Column(
                children: <Widget>[
                  // This is button is present so that we can tap it and
                  // simulate a frame being drawn.
                  ElevatedButton(
                    onPressed: () => {},
                    child: const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('displays banner messages', (WidgetTester tester) async {
      await tester.pumpWidget(buildBannerMessages());
      expect(find.byKey(k1), findsNothing);
      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      expect(find.byKey(k2), findsNothing);
      bannerMessages.addMessage(testMessage2);
      await pumpTestFrame(tester);
      expect(find.byKey(k2), findsOneWidget);
    });

    testWidgets('does not add duplicate messages', (WidgetTester tester) async {
      await tester.pumpWidget(buildBannerMessages());
      expect(find.byKey(k1), findsNothing);

      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      // Verify there is still only one message after adding the duplicate.
      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);
    });

    testWidgets('removes and dismisses messages', (WidgetTester tester) async {
      await tester.pumpWidget(buildBannerMessages());
      expect(find.byKey(k1), findsNothing);
      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      bannerMessages.removeMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message can be re-added, since it was not removed with
      // `dismiss = true`.
      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      // Remove message by key this time.
      bannerMessages.removeMessageByKey(k1, testMessage1ScreenId);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message can be re-added, since it was not removed with
      // `dismiss = true`.
      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      bannerMessages.removeMessage(testMessage1, dismiss: true);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message cannot be re-added, since it was removed with
      // `dismiss = true`.
      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);
    });

    testWidgets('messages self dismiss', (WidgetTester tester) async {
      await tester.pumpWidget(buildBannerMessages());
      expect(find.byKey(k1), findsNothing);
      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message cannot be re-added, since it was removed with
      // `dismiss = true`.
      bannerMessages.addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);
    });

    testWidgets(
      'dismissed messages can be re-added when ignoreIfAlreadyDismissed is false',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildBannerMessages());
        expect(find.byKey(k1), findsNothing);
        bannerMessages.addMessage(testMessage1);
        await pumpTestFrame(tester);
        expect(find.byKey(k1), findsOneWidget);

        await tester.tap(find.byType(IconButton));
        await pumpTestFrame(tester);
        expect(find.byKey(k1), findsNothing);

        // Verify message can be re-added with ignoreIfAlreadyDismissed = false.
        bannerMessages.addMessage(
          testMessage1,
          ignoreIfAlreadyDismissed: false,
        );
        await pumpTestFrame(tester);
        expect(find.byKey(k1), findsOneWidget);
      },
    );
  });
}

final testMessage1ScreenId = SimpleScreen.id;
final testMessage2ScreenId = SimpleScreen.id;
const k1 = Key('test message 1');
const k2 = Key('test message 2');
final testMessage1 = BannerMessage(
  key: k1,
  textSpans: const [TextSpan(text: 'Test Message 1')],
  screenId: testMessage1ScreenId,
  messageType: BannerMessageType.warning,
);
final testMessage2 = BannerMessage(
  key: k2,
  textSpans: const [TextSpan(text: 'Test Message 2')],
  screenId: testMessage2ScreenId,
  messageType: BannerMessageType.warning,
);

// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/profiler/profiler_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/banner_messages.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/framework/scaffold.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late BannerMessagesController controller;
  late FakeServiceManager fakeServiceManager;

  setUp(() {
    controller = BannerMessagesController();
    fakeServiceManager = FakeServiceManager();
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
  });

  group('BannerMessages', () {
    late BuildContext buildContext;

    /// Pumps a test frame so that we can ensure post frame callbacks are
    /// executed.
    Future<void> pumpTestFrame(WidgetTester tester) async {
      // Tap the raised Button in order to draw a frame.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
    }

    Widget buildBannerMessages() {
      return wrapWithControllers(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BannerMessages(
            screen: SimpleScreen(
              Builder(
                builder: (context) {
                  buildContext = context;
                  return Column(
                    children: <Widget>[
                      // This is button is present so that we can tap it and
                      // simulate a frame being drawn.
                      ElevatedButton(
                        onPressed: () => {},
                        child: const SizedBox(),
                      ),
                    ],
                  );
                },
              ),
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
      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      expect(find.byKey(k2), findsNothing);
      bannerMessagesController(buildContext).addMessage(testMessage2);
      await pumpTestFrame(tester);
      expect(find.byKey(k2), findsOneWidget);
    });

    testWidgets('does not add duplicate messages', (WidgetTester tester) async {
      final bannerMessages = buildBannerMessages();
      await tester.pumpWidget(bannerMessages);
      expect(find.byKey(k1), findsNothing);

      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      // Verify there is still only one message after adding the duplicate.
      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);
    });

    testWidgets('removes and dismisses messages', (WidgetTester tester) async {
      final bannerMessages = buildBannerMessages();
      await tester.pumpWidget(bannerMessages);
      expect(find.byKey(k1), findsNothing);
      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      bannerMessagesController(buildContext).removeMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message can be re-added, since it was not removed with
      // `dismiss = true`.
      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      // Remove message by key this time.
      bannerMessagesController(buildContext)
          .removeMessageByKey(k1, testMessage1ScreenId);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message can be re-added, since it was not removed with
      // `dismiss = true`.
      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      bannerMessagesController(buildContext)
          .removeMessage(testMessage1, dismiss: true);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message cannot be re-added, since it was removed with
      // `dismiss = true`.
      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);
    });

    testWidgets('messages self dismiss', (WidgetTester tester) async {
      final bannerMessages = buildBannerMessages();
      await tester.pumpWidget(bannerMessages);
      expect(find.byKey(k1), findsNothing);
      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsOneWidget);

      await tester.tap(find.byType(CircularIconButton));
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);

      // Verify message cannot be re-added, since it was removed with
      // `dismiss = true`.
      bannerMessagesController(buildContext).addMessage(testMessage1);
      await pumpTestFrame(tester);
      expect(find.byKey(k1), findsNothing);
    });
  });
}

BannerMessagesController bannerMessagesController(BuildContext context) {
  return Provider.of<BannerMessagesController>(context, listen: false);
}

const testMessage1ScreenId = SimpleScreen.id;
const testMessage2ScreenId = SimpleScreen.id;
const testMessage3ScreenId = ProfilerScreen.id;
const k1 = Key('test message 1');
const k2 = Key('test message 2');
const k3 = Key('test message 3');
const testMessage1 = BannerMessage(
  key: k1,
  textSpans: [TextSpan(text: 'Test Message 1')],
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  screenId: testMessage1ScreenId,
  headerText: 'WARNING',
);
const testMessage2 = BannerMessage(
  key: k2,
  textSpans: [TextSpan(text: 'Test Message 2')],
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  screenId: testMessage2ScreenId,
  headerText: 'WARNING',
);
const testMessage3 = BannerMessage(
  key: k3,
  textSpans: [TextSpan(text: 'Test Message 3')],
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  screenId: testMessage3ScreenId,
  headerText: 'WARNING',
);

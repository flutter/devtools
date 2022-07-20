// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notifications', () {
    setGlobal(IdeTheme, IdeTheme());

    Widget buildNotificationsWithButtonToPush(String text) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Notifications(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => notificationService.push(text),
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
    }

    testWidgets('displays notifications', (WidgetTester tester) async {
      const notification = 'This is a notification!';
      await tester.pumpWidget(buildNotificationsWithButtonToPush(notification));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text(notification), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text(notification), findsNWidgets(2));
    });

    testWidgets('notifications expire', (WidgetTester tester) async {
      const notification = 'This is a notification!';
      await tester.pumpWidget(buildNotificationsWithButtonToPush(notification));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text(notification), findsOneWidget);

      // Wait for the notification to disappear.
      await tester.pumpAndSettle(Notifications.defaultDuration);
      expect(find.text(notification), findsNothing);
    });

    testWidgets('persist across routes', (WidgetTester tester) async {
      const notification = 'Navigating to /details';
      const detailsKey = Key('details page');
      var timesPressed = 0;
      Widget build() {
        return MaterialApp(
          builder: (context, child) => Notifications(child: child!),
          routes: {
            '/': (context) {
              return ElevatedButton(
                onPressed: () {
                  if (timesPressed == 0) {
                    notificationService.push(notification);
                  } else {
                    Navigator.of(context).pushNamed('/details');
                  }
                  timesPressed++;
                },
                child: const SizedBox(),
              );
            },
            '/details': (context) {
              return const SizedBox(key: detailsKey);
            }
          },
        );
      }

      await tester.pumpWidget(build());
      expect(find.text(notification), findsNothing);
      expect(find.byKey(detailsKey), findsNothing);
      // The first tap of the button will show the notification.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text(notification), findsOneWidget);
      expect(find.byKey(detailsKey), findsNothing);

      // The second tap will navigate to /details.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text(notification), findsOneWidget);
      expect(find.byKey(detailsKey), findsOneWidget);
    });
  });
}

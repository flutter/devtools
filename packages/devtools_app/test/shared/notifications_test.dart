// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/framework/notifications_view.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notifications', () {
    Future<void> showNotification(
      void Function() triggerNotification, {
      required WidgetTester tester,
    }) async {
      final notificationsWidget = Directionality(
        textDirection: TextDirection.ltr,
        child: NotificationsView(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: triggerNotification,
                child: const SizedBox(),
              );
            },
          ),
        ),
      );

      await tester.pumpWidget(notificationsWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
    }

    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());
    });

    testWidgets('displays notifications', (WidgetTester tester) async {
      const notification = 'This is a notification!';
      await showNotification(
        () => notificationService.push(notification),
        tester: tester,
      );

      expect(find.text(notification), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text(notification), findsNWidgets(2));
    });

    testWidgets(
      'dismissible notifications can be dismissed',
      (WidgetTester tester) async {
        const notification = 'This is a notification!';
        await showNotification(
          () => notificationService.push(notification, isDismissible: true),
          tester: tester,
        );

        final closeButton = find.byType(IconButton);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);

        // Verify the notification has been dismissed:
        await tester.pumpAndSettle();
        expect(find.text(notification), findsNothing);
      },
    );

    testWidgets(
      'non-dismissible notifications expire',
      (WidgetTester tester) async {
        const notification = 'This is a notification!';
        await showNotification(
          () => notificationService.push(notification),
          tester: tester,
        );

        expect(find.text(notification), findsOneWidget);

        // Wait for the notification to disappear.
        await tester.pumpAndSettle(NotificationMessage.defaultDuration);
        expect(find.text(notification), findsNothing);
      },
    );

    testWidgets(
      'dismissible notifications do not expire',
      (WidgetTester tester) async {
        const notification = 'This is a notification!';
        await showNotification(
          () => notificationService.push(notification, isDismissible: true),
          tester: tester,
        );

        // Wait for the default dismiss duration.
        await tester.pumpAndSettle(NotificationMessage.defaultDuration);

        // Verify the notification is still there.
        expect(find.text(notification), findsOneWidget);
      },
    );

    testWidgets('persist across routes', (WidgetTester tester) async {
      const notification = 'Navigating to /details';
      const detailsKey = Key('details page');
      var timesPressed = 0;
      Widget build() {
        return MaterialApp(
          builder: (context, child) => NotificationsView(child: child!),
          routes: {
            '/': (context) {
              return ElevatedButton(
                onPressed: () {
                  if (timesPressed == 0) {
                    notificationService.push(notification);
                  } else {
                    unawaited(Navigator.of(context).pushNamed('/details'));
                  }
                  timesPressed++;
                },
                child: const SizedBox(),
              );
            },
            '/details': (context) {
              return const SizedBox(key: detailsKey);
            },
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

    group('Error notifications', () {
      testWidgets('displays errors', (WidgetTester tester) async {
        const errorMessage = 'This is an error!';
        await showNotification(
          () => notificationService.push(errorMessage),
          tester: tester,
        );

        expect(find.text(errorMessage), findsOneWidget);
      });

      testWidgets('are reportable by default', (WidgetTester tester) async {
        const errorMessage = 'This is an error!';
        await showNotification(
          () => notificationService.pushError(errorMessage),
          tester: tester,
        );

        expect(
          find.widgetWithText(OutlinedButton, 'Report error'),
          findsOneWidget,
        );
      });

      testWidgets('are dismissable by default', (WidgetTester tester) async {
        const errorMessage = 'This is an error!';
        await showNotification(
          () => notificationService.pushError(errorMessage),
          tester: tester,
        );

        final closeButton = find.byType(IconButton);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);

        // Verify the error has been dismissed:
        await tester.pumpAndSettle();
        expect(find.text(errorMessage), findsNothing);
      });
    });
  });
}

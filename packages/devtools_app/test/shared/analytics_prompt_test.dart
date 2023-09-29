// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/analytics/prompt.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const windowSize = Size(2000.0, 1000.0);

void main() {
  late AnalyticsController controller;

  late bool didCallEnableAnalytics;

  Widget wrapWithAnalytics(
    Widget child, {
    AnalyticsController? controllerToUse,
  }) {
    if (controllerToUse != null) {
      controller = controllerToUse;
    }

    return Provider<AnalyticsController>.value(
      value: controller,
      child: child,
    );
  }

  group('AnalyticsPrompt', () {
    setUp(() {
      didCallEnableAnalytics = false;
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
      setGlobal(IdeTheme, IdeTheme());
    });
    group('with analytics enabled', () {
      group('on first run', () {
        setUp(() {
          didCallEnableAnalytics = false;
          controller = AnalyticsController(
            enabled: true,
            firstRun: true,
            onEnableAnalytics: () {
              didCallEnableAnalytics = true;
            },
          );
        });

        testWidgetsWithWindowSize(
          'does not display prompt or call enable analytics',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isFalse);
            final prompt = wrapWithAnalytics(
              const AnalyticsPrompt(
                child: Text('Child Text'),
              ),
            );
            await tester.pumpWidget(wrap(prompt));
            await tester.pump();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsNothing,
            );
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isFalse);
          },
        );

        testWidgetsWithWindowSize(
          'sets up analytics on controller creation',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsInitialized, isTrue);
          },
        );
      });

      group('on non-first run', () {
        setUp(() {
          controller = AnalyticsController(
            enabled: true,
            firstRun: false,
            onEnableAnalytics: () {
              didCallEnableAnalytics = true;
            },
          );
        });

        testWidgetsWithWindowSize(
          'does not display prompt or call enable analytics',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isFalse);
            final prompt = wrapWithAnalytics(
              const AnalyticsPrompt(
                child: Text('Child Text'),
              ),
            );
            await tester.pumpWidget(wrap(prompt));
            await tester.pump();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsNothing,
            );
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isFalse);
          },
        );

        testWidgetsWithWindowSize(
          'sets up analytics on controller creation',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsInitialized, isTrue);
          },
        );
      });

      testWidgetsWithWindowSize(
        'displays the child',
        windowSize,
        (WidgetTester tester) async {
          final prompt = wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
            controllerToUse:
                AnalyticsController(enabled: true, firstRun: false),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(find.text('Child Text'), findsOneWidget);
        },
      );
    });

    group('without analytics enabled', () {
      group('on first run', () {
        setUp(() {
          controller = AnalyticsController(
            enabled: false,
            firstRun: true,
            onEnableAnalytics: () {
              didCallEnableAnalytics = true;
            },
          );
        });

        testWidgetsWithWindowSize(
          'displays prompt and calls enables analytics',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isTrue);
            final prompt = wrapWithAnalytics(
              const AnalyticsPrompt(
                child: Text('Child Text'),
              ),
            );
            await tester.pumpWidget(wrap(prompt));
            await tester.pump();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsOneWidget,
            );
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isTrue);
          },
        );

        testWidgetsWithWindowSize(
          'sets up analytics on controller creation',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsInitialized, isTrue);
          },
        );

        testWidgetsWithWindowSize(
          'close button closes prompt without disabling analytics',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isTrue);
            final prompt = wrapWithAnalytics(
              const AnalyticsPrompt(
                child: Text('Child Text'),
              ),
            );
            await tester.pumpWidget(wrap(prompt));
            await tester.pump();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsOneWidget,
            );
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isTrue);

            final closeButtonFinder = find.byType(IconButton);
            expect(closeButtonFinder, findsOneWidget);
            await tester.tap(closeButtonFinder);
            await tester.pumpAndSettle();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsNothing,
            );
            expect(controller.analyticsEnabled.value, isTrue);
          },
        );

        testWidgetsWithWindowSize(
          'Sounds Good button closes prompt without disabling analytics',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isTrue);
            final prompt = wrapWithAnalytics(
              const AnalyticsPrompt(
                child: Text('Child Text'),
              ),
            );
            await tester.pumpWidget(wrap(prompt));
            await tester.pump();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsOneWidget,
            );
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isTrue);

            final soundsGoodFinder = find.text('Sounds good!');
            expect(soundsGoodFinder, findsOneWidget);
            await tester.tap(soundsGoodFinder);
            await tester.pumpAndSettle();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsNothing,
            );
            expect(controller.analyticsEnabled.value, isTrue);
          },
        );

        testWidgetsWithWindowSize(
          'No Thanks button closes prompt and disables analytics',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isTrue);
            final prompt = wrapWithAnalytics(
              const AnalyticsPrompt(
                child: Text('Child Text'),
              ),
            );
            await tester.pumpWidget(wrap(prompt));
            await tester.pump();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsOneWidget,
            );
            expect(controller.analyticsEnabled.value, isTrue);
            expect(didCallEnableAnalytics, isTrue);

            final noThanksFinder = find.text('No thanks.');
            expect(noThanksFinder, findsOneWidget);
            await tester.tap(noThanksFinder);
            await tester.pumpAndSettle();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsNothing,
            );
            expect(controller.analyticsEnabled.value, isFalse);
          },
        );
      });

      group('on non-first run', () {
        setUp(() {
          controller = AnalyticsController(
            enabled: false,
            firstRun: false,
            onEnableAnalytics: () {
              didCallEnableAnalytics = true;
            },
          );
        });

        testWidgetsWithWindowSize(
          'does not display prompt or enable analytics from prompt',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsEnabled.value, isFalse);
            expect(didCallEnableAnalytics, isFalse);
            final prompt = wrapWithAnalytics(
              const AnalyticsPrompt(
                child: Text('Child Text'),
              ),
            );
            await tester.pumpWidget(wrap(prompt));
            await tester.pump();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsNothing,
            );
            expect(controller.analyticsEnabled.value, isFalse);
            expect(didCallEnableAnalytics, isFalse);
          },
        );

        testWidgetsWithWindowSize(
          'does not set up analytics on controller creation',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsInitialized, isFalse);
          },
        );
      });

      testWidgetsWithWindowSize(
        'displays the child',
        windowSize,
        (WidgetTester tester) async {
          final prompt = wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
            controllerToUse:
                AnalyticsController(enabled: false, firstRun: false),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(find.text('Child Text'), findsOneWidget);
        },
      );
    });
  });
}

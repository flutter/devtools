// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/analytics/prompt.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_analytics/src/constants.dart' as ua;

const windowSize = Size(2000.0, 1000.0);

void main() {
  late AnalyticsController controller;

  late bool didCallEnableAnalytics;
  late bool didMarkConsentMessageAsShown;

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

  test('Unit test parseAnalyticsConsentMessage with consent message', () {
    final result = parseAnalyticsConsentMessage(ua.kToolsMessage);

    expect(result, isNotEmpty);
    expect(result, hasLength(3));
  });

  group('AnalyticsPrompt', () {
    setUp(() {
      didCallEnableAnalytics = false;
      didMarkConsentMessageAsShown = false;
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(DTDManager, MockDTDManager());
    });

    group('with analytics enabled', () {
      group('on first run', () {
        setUp(() {
          didCallEnableAnalytics = false;
          controller = TestAnalyticsController(
            enabled: true,
            shouldShowConsentMessage: true,
            legacyOnEnableAnalytics: () {
              didCallEnableAnalytics = true;
            },
            onMarkConsentMessageAsShown: () {
              didMarkConsentMessageAsShown = true;
            },
            consentMessage: 'fake message',
          );
        });

        testWidgetsWithWindowSize(
          'displays the prompt and calls enable analytics',
          windowSize,
          (WidgetTester tester) async {
            expect(controller.analyticsEnabled.value, isTrue);
            expect(
              didCallEnableAnalytics,
              isTrue,
              reason: 'Analytics is enabled on first run',
            );
            expect(didMarkConsentMessageAsShown, isFalse);
            final prompt = wrapWithAnalytics(
              const AnalyticsPrompt(
                child: Text('Child Text'),
              ),
            );
            await tester.pumpWidget(wrap(prompt));
            await tester.pump();
            expect(
              find.text('Send usage statistics for DevTools?'),
              findsOne,
              reason: 'The consent message should be shown on first run',
            );
            expect(controller.analyticsEnabled.value, isTrue);
            expect(
              didMarkConsentMessageAsShown,
              isTrue,
              reason:
                  'The consent message should be marked as shown after displaying',
            );
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
            shouldShowConsentMessage: false,
            legacyOnEnableAnalytics: () {
              didCallEnableAnalytics = true;
            },
            consentMessage: 'fake message',
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
            controllerToUse: AnalyticsController(
              enabled: true,
              shouldShowConsentMessage: false,
              consentMessage: 'fake message',
            ),
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
            shouldShowConsentMessage: true,
            legacyOnEnableAnalytics: () {
              didCallEnableAnalytics = true;
            },
            consentMessage: 'fake message',
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
            shouldShowConsentMessage: false,
            legacyOnEnableAnalytics: () {
              didCallEnableAnalytics = true;
            },
            consentMessage: 'fake message',
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
            controllerToUse: AnalyticsController(
              enabled: false,
              shouldShowConsentMessage: false,
              consentMessage: 'fake message',
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(find.text('Child Text'), findsOneWidget);
        },
      );
    });
  });
}

class TestAnalyticsController extends AnalyticsController {
  TestAnalyticsController({
    required super.enabled,
    required super.shouldShowConsentMessage,
    required super.consentMessage,
    super.legacyOnEnableAnalytics,
    super.legacyOnDisableAnalytics,
    super.legacyOnSetupAnalytics,
    this.onMarkConsentMessageAsShown,
  });

  VoidCallback? onMarkConsentMessageAsShown;

  @override
  Future<void> markConsentMessageAsShown() async {
    await super.markConsentMessageAsShown();
    onMarkConsentMessageAsShown?.call();
  }
}

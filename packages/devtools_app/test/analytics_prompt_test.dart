// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_app/src/analytics/analytics_controller.dart';
import 'package:devtools_app/src/analytics/prompt.dart';
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const windowSize = Size(2000.0, 1000.0);

void main() {
  AnalyticsController _controller;

  bool didCallEnableAnalytics;

  Widget _wrapWithAnalytics(
    Widget child, {
    AnalyticsController controller,
  }) {
    _controller ??= controller;
    return wrapWithAnalytics(child, controller: _controller);
  }

  group('AnalyticsPrompt', () {
    setUp(() {
      didCallEnableAnalytics = false;
      setGlobal(ServiceConnectionManager, FakeServiceManager());
      setGlobal(IdeTheme, IdeTheme());
    });
    group('with analytics enabled', () {
      group('on first run', () {
        setUp(() {
          didCallEnableAnalytics = false;
          _controller = AnalyticsController(
            enabled: true,
            firstRun: true,
            onEnableAnalytics: () async {
              didCallEnableAnalytics = true;
            },
          );
        });

        testWidgetsWithWindowSize(
            'does not display prompt or call enable analytics', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isFalse);
          final prompt = _wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isFalse);
        });

        testWidgetsWithWindowSize(
            'sets up analytics on controller creation', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsInitialized, isTrue);
        });
      });

      group('on non-first run', () {
        setUp(() {
          _controller = AnalyticsController(
            enabled: true,
            firstRun: false,
            onEnableAnalytics: () async {
              didCallEnableAnalytics = true;
            },
          );
        });

        testWidgetsWithWindowSize(
            'does not display prompt or call enable analytics', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isFalse);
          final prompt = _wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isFalse);
        });

        testWidgetsWithWindowSize(
            'sets up analytics on controller creation', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsInitialized, isTrue);
        });
      });

      testWidgetsWithWindowSize('displays the child', windowSize,
          (WidgetTester tester) async {
        final prompt = _wrapWithAnalytics(
          const AnalyticsPrompt(
            child: Text('Child Text'),
          ),
          controller: AnalyticsController(enabled: true, firstRun: false),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });

    group('without analytics enabled', () {
      group('on first run', () {
        setUp(() {
          _controller = AnalyticsController(
            enabled: false,
            firstRun: true,
            onEnableAnalytics: () async {
              didCallEnableAnalytics = true;
            },
          );
        });

        testWidgetsWithWindowSize(
            'displays prompt and calls enables analytics', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isTrue);
          final prompt = _wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isTrue);
        });

        testWidgetsWithWindowSize(
            'sets up analytics on controller creation', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsInitialized, isTrue);
        });

        testWidgetsWithWindowSize(
            'close button closes prompt without disabling analytics',
            windowSize, (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isTrue);
          final prompt = _wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isTrue);

          final closeButtonFinder = find.byType(CircularIconButton);
          expect(closeButtonFinder, findsOneWidget);
          await tester.tap(closeButtonFinder);
          await tester.pumpAndSettle();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_controller.analyticsEnabled.value, isTrue);
        });

        testWidgetsWithWindowSize(
            'Sounds Good button closes prompt without disabling analytics',
            windowSize, (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isTrue);
          final prompt = _wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isTrue);

          final soundsGoodFinder = find.text('Sounds good!');
          expect(soundsGoodFinder, findsOneWidget);
          await tester.tap(soundsGoodFinder);
          await tester.pumpAndSettle();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_controller.analyticsEnabled.value, isTrue);
        });

        testWidgetsWithWindowSize(
            'No Thanks button closes prompt and disables analytics', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isTrue);
          final prompt = _wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(didCallEnableAnalytics, isTrue);

          final noThanksFinder = find.text('No thanks.');
          expect(noThanksFinder, findsOneWidget);
          await tester.tap(noThanksFinder);
          await tester.pumpAndSettle();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_controller.analyticsEnabled.value, isFalse);
        });
      });

      group('on non-first run', () {
        setUp(() {
          _controller = AnalyticsController(
            enabled: false,
            firstRun: false,
            onEnableAnalytics: () async {
              didCallEnableAnalytics = true;
            },
          );
        });

        testWidgetsWithWindowSize(
            'does not display prompt or enable analytics from prompt',
            windowSize, (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isFalse);
          expect(didCallEnableAnalytics, isFalse);
          final prompt = _wrapWithAnalytics(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_controller.analyticsEnabled.value, isFalse);
          expect(didCallEnableAnalytics, isFalse);
        });

        testWidgetsWithWindowSize(
            'does not set up analytics on controller creation', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsInitialized, isFalse);
        });
      });

      testWidgetsWithWindowSize('displays the child', windowSize,
          (WidgetTester tester) async {
        final prompt = _wrapWithAnalytics(
          const AnalyticsPrompt(
            child: Text('Child Text'),
          ),
          controller: AnalyticsController(enabled: false, firstRun: false),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });
  });
}

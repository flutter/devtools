// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/analytics/analytics_controller.dart';
import 'package:devtools_app/src/analytics/prompt.dart';
import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

class FakeController extends AnalyticsController {
  FakeController({
    @required bool enabled,
    @required bool firstRun,
  })  : _analyticsEnabled = ValueNotifier<bool>(enabled),
        _shouldPrompt = ValueNotifier<bool>(firstRun && !enabled) {
    if (_shouldPrompt.value) {
      toggleAnalyticsEnabled(true);
    }
    if (_analyticsEnabled.value) {
      setUpAnalytics();
    }
  }

  @override
  ValueListenable<bool> get analyticsEnabled => _analyticsEnabled;
  final ValueNotifier<bool> _analyticsEnabled;

  @override
  ValueListenable<bool> get shouldPrompt => _shouldPrompt;
  final ValueNotifier<bool> _shouldPrompt;

  bool didCallEnableAnalytics = false;

  @override
  bool get analyticsInitialized => _analyticsInitialized;
  bool _analyticsInitialized = false;

  @override
  Future<void> toggleAnalyticsEnabled(bool enabled) async {
    if (enabled) {
      _analyticsEnabled.value = true;
      didCallEnableAnalytics = true;
      if (!_analyticsInitialized) {
        setUpAnalytics();
      }
    } else {
      _analyticsEnabled.value = false;
      hidePrompt();
    }
  }

  @override
  void setUpAnalytics() {
    _analyticsInitialized = true;
  }

  @override
  void hidePrompt() {
    _shouldPrompt.value = false;
  }
}

const windowSize = Size(2000.0, 1000.0);

void main() {
  FakeController _controller;

  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
  });

  Widget _wrapWithAnalytics(
    Widget child, {
    AnalyticsController controller,
  }) {
    _controller ??= controller;
    return wrapWithAnalytics(child, controller: _controller);
  }

  group('AnalyticsPrompt', () {
    group('with analytics enabled', () {
      group('on first run', () {
        setUp(() {
          _controller = FakeController(enabled: true, firstRun: true);
        });

        testWidgetsWithWindowSize(
            'does not display prompt or call enable analytics', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(_controller.didCallEnableAnalytics, isFalse);
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
          expect(_controller.didCallEnableAnalytics, isFalse);
        });

        testWidgetsWithWindowSize(
            'sets up analytics on controller creation', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsInitialized, isTrue);
        });
      });

      group('on non-first run', () {
        setUp(() {
          _controller = FakeController(enabled: true, firstRun: false);
        });

        testWidgetsWithWindowSize(
            'does not display prompt or call enable analytics', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(_controller.didCallEnableAnalytics, isFalse);
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
          expect(_controller.didCallEnableAnalytics, isFalse);
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
          controller: FakeController(enabled: true, firstRun: false),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });

    group('without analytics enabled', () {
      group('on first run', () {
        setUp(() {
          _controller = FakeController(enabled: false, firstRun: true);
        });

        testWidgetsWithWindowSize(
            'displays prompt and calls enables analytics', windowSize,
            (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isTrue);
          expect(_controller.didCallEnableAnalytics, isTrue);
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
          expect(_controller.didCallEnableAnalytics, isTrue);
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
          expect(_controller.didCallEnableAnalytics, isTrue);
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
          expect(_controller.didCallEnableAnalytics, isTrue);

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
          expect(_controller.didCallEnableAnalytics, isTrue);
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
          expect(_controller.didCallEnableAnalytics, isTrue);

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
          expect(_controller.didCallEnableAnalytics, isTrue);
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
          expect(_controller.didCallEnableAnalytics, isTrue);

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
          _controller = FakeController(enabled: false, firstRun: false);
        });

        testWidgetsWithWindowSize(
            'does not display prompt or enable analytics from prompt',
            windowSize, (WidgetTester tester) async {
          expect(_controller.analyticsEnabled.value, isFalse);
          expect(_controller.didCallEnableAnalytics, isFalse);
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
          expect(_controller.didCallEnableAnalytics, isFalse);
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
          controller: FakeController(enabled: false, firstRun: false),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });
  });
}

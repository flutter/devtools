// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/analytics/prompt.dart';
import 'package:devtools_app/src/analytics/provider.dart';
import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

class FakeProvider implements AnalyticsProvider {
  FakeProvider({
    @required bool enabled,
    @required bool firstRun,
  })  : _analyticsEnabled = ValueNotifier<bool>(enabled),
        _shouldPrompt = ValueNotifier<bool>(firstRun && !enabled);

  @override
  ValueListenable<bool> get analyticsEnabled => _analyticsEnabled;
  final ValueNotifier<bool> _analyticsEnabled;

  @override
  ValueListenable<bool> get shouldPrompt => _shouldPrompt;
  final ValueNotifier<bool> _shouldPrompt;

  bool didEnableAnalyticsFromPrompt = false;

  bool didSetUpAnalytics = false;

  @override
  void enableAnalytics() {
    _analyticsEnabled.value = true;
    didEnableAnalyticsFromPrompt = true;
  }

  @override
  void disableAnalytics() {
    _analyticsEnabled.value = false;
  }

  @override
  void setUpAnalytics() {
    didSetUpAnalytics = true;
  }
}

const windowSize = Size(2000.0, 1000.0);

void main() {
  FakeProvider _provider;

  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
  });

  Widget _wrapWithAnalyticsProvider(
    Widget child, {
    AnalyticsProvider provider,
  }) {
    _provider ??= provider;
    return wrapWithAnalyticsProvider(child, provider: _provider);
  }

  group('AnalyticsPrompt', () {
    group('with analytics enabled', () {
      group('on first run', () {
        setUp(() {
          _provider = FakeProvider(enabled: true, firstRun: true);
        });

        testWidgetsWithWindowSize(
            'does not display prompt or enable analytics from prompt',
            windowSize, (WidgetTester tester) async {
          expect(_provider.analyticsEnabled.value, isTrue);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.analyticsEnabled.value, isTrue);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
        });

        testWidgetsWithWindowSize('sets up analytics', windowSize,
            (WidgetTester tester) async {
          expect(_provider.didSetUpAnalytics, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.didSetUpAnalytics, isTrue);
        });
      });

      group('on non-first run', () {
        setUp(() {
          _provider = FakeProvider(enabled: true, firstRun: false);
        });

        testWidgetsWithWindowSize(
            'does not display prompt or enable analytics from prompt',
            windowSize, (WidgetTester tester) async {
          expect(_provider.analyticsEnabled.value, isTrue);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.analyticsEnabled.value, isTrue);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
        });

        testWidgetsWithWindowSize('sets up analytics', windowSize,
            (WidgetTester tester) async {
          expect(_provider.didSetUpAnalytics, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.didSetUpAnalytics, isTrue);
        });
      });

      testWidgetsWithWindowSize('displays the child', windowSize,
          (WidgetTester tester) async {
        final prompt = _wrapWithAnalyticsProvider(
          const AnalyticsPrompt(
            child: Text('Child Text'),
          ),
          provider: FakeProvider(enabled: true, firstRun: false),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });

    group('without analytics enabled', () {
      group('on first run', () {
        setUp(() {
          _provider = FakeProvider(enabled: false, firstRun: true);
        });

        testWidgetsWithWindowSize(
            'displays prompt and enables analytics from prompt', windowSize,
            (WidgetTester tester) async {
          expect(_provider.analyticsEnabled.value, isFalse);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_provider.analyticsEnabled.value, isTrue);
          expect(_provider.didEnableAnalyticsFromPrompt, isTrue);
        });

        testWidgetsWithWindowSize('sets up analytics', windowSize,
            (WidgetTester tester) async {
          expect(_provider.didSetUpAnalytics, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_provider.didSetUpAnalytics, isTrue);
        });

        testWidgetsWithWindowSize(
            'close button closes prompt without disabling analytics',
            windowSize, (WidgetTester tester) async {
          expect(_provider.analyticsEnabled.value, isFalse);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_provider.analyticsEnabled.value, isTrue);
          expect(_provider.didEnableAnalyticsFromPrompt, isTrue);

          final closeButtonFinder = find.byType(CircularIconButton);
          expect(closeButtonFinder, findsOneWidget);
          await tester.tap(closeButtonFinder);
          await tester.pumpAndSettle();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.analyticsEnabled.value, isTrue);
        });

        testWidgetsWithWindowSize(
            'Sounds Good button closes prompt without disabling analytics',
            windowSize, (WidgetTester tester) async {
          expect(_provider.analyticsEnabled.value, isFalse);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_provider.analyticsEnabled.value, isTrue);
          expect(_provider.didEnableAnalyticsFromPrompt, isTrue);

          final soundsGoodFinder = find.text('Sounds good!');
          expect(soundsGoodFinder, findsOneWidget);
          await tester.tap(soundsGoodFinder);
          await tester.pumpAndSettle();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.analyticsEnabled.value, isTrue);
        });

        testWidgetsWithWindowSize(
            'No Thanks button closes prompt and disables analytics', windowSize,
            (WidgetTester tester) async {
          expect(_provider.analyticsEnabled.value, isFalse);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsOneWidget);
          expect(_provider.analyticsEnabled.value, isTrue);
          expect(_provider.didEnableAnalyticsFromPrompt, isTrue);

          final noThanksFinder = find.text('No thanks.');
          expect(noThanksFinder, findsOneWidget);
          await tester.tap(noThanksFinder);
          await tester.pumpAndSettle();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.analyticsEnabled.value, isFalse);
        });
      });

      group('on non-first run', () {
        setUp(() {
          _provider = FakeProvider(enabled: false, firstRun: false);
        });

        testWidgetsWithWindowSize(
            'does not display prompt or enable analytics from prompt',
            windowSize, (WidgetTester tester) async {
          expect(_provider.analyticsEnabled.value, isFalse);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.analyticsEnabled.value, isFalse);
          expect(_provider.didEnableAnalyticsFromPrompt, isFalse);
        });

        testWidgetsWithWindowSize('does not set up analytics', windowSize,
            (WidgetTester tester) async {
          expect(_provider.didSetUpAnalytics, isFalse);
          final prompt = _wrapWithAnalyticsProvider(
            const AnalyticsPrompt(
              child: Text('Child Text'),
            ),
          );
          await tester.pumpWidget(wrap(prompt));
          await tester.pump();
          expect(
              find.text('Send usage statistics for DevTools?'), findsNothing);
          expect(_provider.didSetUpAnalytics, isFalse);
        });
      });

      testWidgetsWithWindowSize('displays the child', windowSize,
          (WidgetTester tester) async {
        final prompt = _wrapWithAnalyticsProvider(
          const AnalyticsPrompt(
            child: Text('Child Text'),
          ),
          provider: FakeProvider(enabled: false, firstRun: false),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });
  });
}

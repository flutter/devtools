// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/analytics_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/wrappers.dart';

class FakeProvider implements AnalyticsProvider {
  FakeProvider({
    this.gtagsEnabled = false,
    this.enabled = false,
    this.firstRun = false,
  });

  final bool gtagsEnabled;
  final bool enabled;
  final bool firstRun;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> get isEnabled async => enabled;

  @override
  Future<bool> get isFirstRun async => firstRun;

  @override
  bool get isGtagsEnabled => gtagsEnabled;

  @override
  void setAllowAnalytics() {}

  @override
  void setDontAllowAnalytics() {}

  @override
  void setUpAnalytics() {}
}

void main() {
  group('AnalyticsNotification', () {
    group('with gtags enabled', () {
      testWidgets('displays notification on first run',
          (WidgetTester tester) async {
        final notification = AnalyticsNotification(
          provider: FakeProvider(gtagsEnabled: true, firstRun: true),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(notification));
        await tester.pump();
        expect(
            find.text('Send usage statistics for DevTools?'), findsOneWidget);
      });

      testWidgets('does not display notification without first run',
          (WidgetTester tester) async {
        final notification = AnalyticsNotification(
          provider: FakeProvider(gtagsEnabled: true),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(notification));
        await tester.pump();
        expect(find.text('Send usage statistics for DevTools?'), findsNothing);
      });

      testWidgets('displays the child', (WidgetTester tester) async {
        final notification = AnalyticsNotification(
          provider: FakeProvider(),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(notification));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });

    group('without gtags enabled', () {
      testWidgets('does not display notification', (WidgetTester tester) async {
        final notification = AnalyticsNotification(
          provider: FakeProvider(),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(notification));
        await tester.pump();
        expect(find.text('Send usage statistics for DevTools?'), findsNothing);
      });

      testWidgets('displays the child', (WidgetTester tester) async {
        final notification = AnalyticsNotification(
          provider: FakeProvider(),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(notification));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });
  });
}

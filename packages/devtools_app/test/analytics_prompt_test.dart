// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/analytics/prompt.dart';
import 'package:devtools_app/src/analytics/provider.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

class FakeProvider implements AnalyticsProvider {
  FakeProvider({
    this.gtagsEnabled = false,
    this.enabled = false,
    this.prompt = false,
  });

  final bool gtagsEnabled;
  final bool enabled;
  final bool prompt;

  @override
  bool get isEnabled => enabled;

  @override
  bool get shouldPrompt => prompt;

  @override
  bool get isGtagsEnabled => gtagsEnabled;

  @override
  void setAllowAnalytics() {}

  @override
  void setDontAllowAnalytics() {}

  @override
  void setUpAnalytics() {}
}

const windowSize = Size(2000.0, 1000.0);

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
  });

  group('AnalyticsPrompt', () {
    group('with gtags enabled', () {
      testWidgetsWithWindowSize(
          'displays prompt if provider indicates to do so', windowSize,
          (WidgetTester tester) async {
        final prompt = AnalyticsPrompt(
          provider: FakeProvider(gtagsEnabled: true, prompt: true),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(
            find.text('Send usage statistics for DevTools?'), findsOneWidget);
      });

      testWidgetsWithWindowSize(
          'does not display prompt without first run', windowSize,
          (WidgetTester tester) async {
        final prompt = AnalyticsPrompt(
          provider: FakeProvider(gtagsEnabled: true),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Send usage statistics for DevTools?'), findsNothing);
      });

      testWidgetsWithWindowSize('displays the child', windowSize,
          (WidgetTester tester) async {
        final prompt = AnalyticsPrompt(
          provider: FakeProvider(),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });

    group('without gtags enabled', () {
      testWidgetsWithWindowSize('does not display prompt', windowSize,
          (WidgetTester tester) async {
        final prompt = AnalyticsPrompt(
          provider: FakeProvider(),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Send usage statistics for DevTools?'), findsNothing);
      });

      testWidgetsWithWindowSize('displays the child', windowSize,
          (WidgetTester tester) async {
        final prompt = AnalyticsPrompt(
          provider: FakeProvider(),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Child Text'), findsOneWidget);
      });
    });
  });
}

// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/analytics/prompt.dart';
import 'package:devtools_app/src/analytics/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('AnalyticsPrompt', () {
    group('with gtags enabled', () {
      testWidgets('displays prompt if provider indicates to do so',
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

      testWidgets('does not display prompt without first run',
          (WidgetTester tester) async {
        final prompt = AnalyticsPrompt(
          provider: FakeProvider(gtagsEnabled: true),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Send usage statistics for DevTools?'), findsNothing);
      });

      testWidgets('displays the child', (WidgetTester tester) async {
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
      testWidgets('does not display prompt', (WidgetTester tester) async {
        final prompt = AnalyticsPrompt(
          provider: FakeProvider(),
          child: const Text('Child Text'),
        );
        await tester.pumpWidget(wrap(prompt));
        await tester.pump();
        expect(find.text('Send usage statistics for DevTools?'), findsNothing);
      });

      testWidgets('displays the child', (WidgetTester tester) async {
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

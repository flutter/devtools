// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// TODO(kenz): add tests for other widgets in common_widgets.dart

void main() {
  const windowSize = Size(1000.0, 1000.0);

  setUp(() {
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(IdeTheme, IdeTheme());
  });

  group('Common widgets', () {
    testWidgetsWithWindowSize(
      'processingInfo builds for progressValue',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const ProcessingInfo(
              progressValue: 0.0,
              processedObject: 'fake object',
            ),
          ),
        );

        final progressIndicatorFinder = find.byType(LinearProgressIndicator);
        LinearProgressIndicator progressIndicator =
            tester.widget(progressIndicatorFinder);

        expect(progressIndicator.value, equals(0.0));

        await tester.pumpWidget(
          wrap(
            const ProcessingInfo(
              progressValue: 0.5,
              processedObject: 'fake object',
            ),
          ),
        );
        progressIndicator = tester.widget(progressIndicatorFinder);
        expect(progressIndicator.value, equals(0.5));
      },
    );
  });

  group('NotifierCheckbox', () {
    bool? findCheckboxValue() {
      final Checkbox checkboxWidget =
          find.byType(Checkbox).evaluate().first.widget as Checkbox;
      return checkboxWidget.value;
    }

    testWidgets('tap checkbox', (WidgetTester tester) async {
      final notifier = ValueNotifier<bool>(false);
      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: notifier)));
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      expect(notifier.value, isFalse);
      expect(findCheckboxValue(), isFalse);
      await tester.tap(checkbox);
      await tester.pump();
      expect(notifier.value, isTrue);
      expect(findCheckboxValue(), isTrue);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(notifier.value, isFalse);
      expect(findCheckboxValue(), isFalse);
    });

    testWidgets('change notifier value', (WidgetTester tester) async {
      final notifier = ValueNotifier<bool>(false);
      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: notifier)));
      expect(notifier.value, isFalse);
      expect(findCheckboxValue(), isFalse);

      notifier.value = true;
      await tester.pump();
      expect(notifier.value, isTrue);
      expect(findCheckboxValue(), isTrue);

      notifier.value = false;
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(notifier.value, isFalse);
      expect(findCheckboxValue(), isFalse);
    });

    testWidgets('change notifier', (WidgetTester tester) async {
      final falseNotifier = ValueNotifier<bool>(false);
      final trueNotifier = ValueNotifier<bool>(true);
      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: falseNotifier)));
      expect(findCheckboxValue(), isFalse);

      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: trueNotifier)));
      expect(findCheckboxValue(), isTrue);

      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: falseNotifier)));
      expect(findCheckboxValue(), isFalse);

      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: trueNotifier)));
      expect(findCheckboxValue(), isTrue);

      // ensure we can modify the value of the notifier and changes are
      // reflected even though this is different than the initial notifier.
      trueNotifier.value = false;
      await tester.pump();
      expect(findCheckboxValue(), isFalse);

      trueNotifier.value = true;
      await tester.pump();
      expect(findCheckboxValue(), isTrue);
    });
  });
}

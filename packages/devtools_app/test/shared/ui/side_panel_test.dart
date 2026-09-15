// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The smallest contrast ratio WCAG 2.1 accepts for body text at level AA.
///
/// See https://www.w3.org/TR/WCAG21/#contrast-minimum.
const _minimumContrastRatio = 4.5;

void main() {
  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
  });

  group('$SidePanelViewer', () {
    // `MarkdownStyleSheet.fromTheme` fills blockquotes with
    // `Colors.blue.shade100` but takes the text color from the theme, so a
    // release note that opens with a blockquote drew `onSurface` text on light
    // blue in the dark theme.
    // Regression test for https://github.com/flutter/devtools/issues/9945.
    for (final useDarkTheme in [true, false]) {
      final themeName = useDarkTheme ? 'dark' : 'light';
      testWidgets('blockquote text is legible in the $themeName theme', (
        tester,
      ) async {
        const summary = 'Release notes for Dart and Flutter DevTools.';
        final controller = SidePanelController();
        await tester.pumpWidget(
          MaterialApp(
            theme: themeFor(
              isDarkTheme: useDarkTheme,
              ideTheme: IdeTheme(),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: useDarkTheme ? darkColorScheme : lightColorScheme,
              ),
            ),
            home: SidePanelViewer(controller: controller),
          ),
        );
        controller.markdown.value = '# Release notes\n\n> $summary';
        controller.toggleVisibility(true);
        await tester.pumpAndSettle();

        final summaryFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText() == summary,
        );
        expect(summaryFinder, findsOneWidget);

        final textColor = _colorOfSpan(
          tester.widget<RichText>(summaryFinder).text,
          summary,
        );
        final fillColor = tester
            .widgetList<DecoratedBox>(
              find.ancestor(
                of: summaryFinder,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .map((decoration) => decoration.color)
            .nonNulls
            .first;

        expect(
          _contrastRatio(textColor!, fillColor),
          greaterThanOrEqualTo(_minimumContrastRatio),
        );
      });
    }
  });
}

/// The color the span holding [text] is painted with, or null if [root] holds
/// no such span.
Color? _colorOfSpan(InlineSpan root, String text) {
  Color? color;
  root.visitChildren((span) {
    if (span is TextSpan && span.text == text) {
      color = span.style?.color;
      return false;
    }
    return true;
  });
  return color;
}

/// The WCAG contrast ratio between [a] and [b], from 1 (identical) to 21
/// (black on white).
double _contrastRatio(Color a, Color b) {
  final luminances = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (luminances.last + 0.05) / (luminances.first + 0.05);
}

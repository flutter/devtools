// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/primitives/utils.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const regularFontStyle = TextStyle(color: Colors.black);
  const fixedFontStyle = TextStyle(color: Colors.blue);

  testWidgets('DartDocConverter handles plain text', (
    WidgetTester tester,
  ) async {
    final converter = DartDocConverter('This is a Dart doc comment.');

    final text = converter.toText(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = converter.toTextSpans(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    expect(text.textSpan?.toPlainText(), equals('This is a Dart doc comment.'));
    expect(_hasStyle(children.first, style: regularFontStyle), isTrue);
  });

  testWidgets('DartDocConverter handles links', (WidgetTester tester) async {
    final converter = DartDocConverter('This is a [link].');
    final text = converter.toText(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = converter.toTextSpans(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final firstChild = children.first;
    final secondChild = children.second;
    final thirdChild = children.third;

    expect(text.textSpan?.toPlainText(), equals('This is a link.'));
    expect(firstChild.toPlainText(), equals('This is a '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('link'));
    expect(_hasStyle(secondChild, style: fixedFontStyle), isTrue);
    expect(thirdChild.toPlainText(), equals('.'));
    expect(_hasStyle(thirdChild, style: regularFontStyle), isTrue);
  });

  testWidgets('DartDocConverter handles code blocks', (
    WidgetTester tester,
  ) async {
    final converter = DartDocConverter('This is `code`.');
    final text = converter.toText(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = converter.toTextSpans(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final firstChild = children.first;
    final secondChild = children.second;
    final thirdChild = children.third;

    expect(text.textSpan?.toPlainText(), equals('This is code.'));
    expect(firstChild.toPlainText(), equals('This is '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('code'));
    expect(_hasStyle(secondChild, style: fixedFontStyle), isTrue);
    expect(thirdChild.toPlainText(), equals('.'));
    expect(_hasStyle(thirdChild, style: regularFontStyle), isTrue);
  });

  testWidgets('DartDocConverter handles mixed content', (
    WidgetTester tester,
  ) async {
    final converter = DartDocConverter('This is [a link] and `some code`.');
    final text = converter.toText(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = converter.toTextSpans(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final firstChild = children.first;
    final secondChild = children.second;
    final thirdChild = children.third;
    final fourthChild = children.fourth;
    final fifthChild = children.fifth;

    expect(
      text.textSpan?.toPlainText(),
      equals('This is a link and some code.'),
    );
    expect(firstChild.toPlainText(), equals('This is '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('a link'));
    expect(_hasStyle(secondChild, style: fixedFontStyle), isTrue);
    expect(thirdChild.toPlainText(), equals(' and '));
    expect(_hasStyle(thirdChild, style: regularFontStyle), isTrue);
    expect(fourthChild.toPlainText(), equals('some code'));
    expect(_hasStyle(fourthChild, style: fixedFontStyle), isTrue);
    expect(fifthChild.toPlainText(), equals('.'));
    expect(_hasStyle(fifthChild, style: regularFontStyle), isTrue);
  });

  testWidgets('DartDocConverter handles unmatched brackets', (
    WidgetTester tester,
  ) async {
    final converter = DartDocConverter('Unmatched [bracket.');
    final text = converter.toText(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = converter.toTextSpans(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final firstChild = children.first;
    final secondChild = children.second;

    expect(text.textSpan?.toPlainText(), equals('Unmatched [bracket.'));
    expect(firstChild.toPlainText(), equals('Unmatched '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('[bracket.'));
    expect(_hasStyle(secondChild, style: regularFontStyle), isTrue);
  });

  testWidgets('DartDocConverter handles unmatched backticks', (
    WidgetTester tester,
  ) async {
    final converter = DartDocConverter('Unmatched `backtick.');
    final text = converter.toText(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = converter.toTextSpans(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final firstChild = children.first;
    final secondChild = children.second;

    expect(text.textSpan?.toPlainText(), equals('Unmatched `backtick.'));
    expect(firstChild.toPlainText(), equals('Unmatched '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('`backtick.'));
    expect(_hasStyle(secondChild, style: regularFontStyle), isTrue);
  });

  testWidgets('DartDocConverter handles @template indicators', (
    WidgetTester tester,
  ) async {
    final converter = DartDocConverter(_stringWithTemplates);
    final text = converter.toText(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    expect(text.textSpan?.toPlainText(), equals(_stringWithoutTemplates));
  });

  testWidgets('DartDocConverter handles empty strings', (
    WidgetTester tester,
  ) async {
    final converter = DartDocConverter('');
    final text = converter.toText(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );

    expect(text.textSpan?.toPlainText(), equals(''));
  });
}

bool _hasStyle(TextSpan span, {required TextStyle style}) =>
    span.style!.color == style.color;

const _stringWithTemplates = '''
This is a Dart doc.
{@template flutter.widgets.someWidget}
Inside of the template.
{@endtemplate}
''';

const _stringWithoutTemplates = '''      
This is a Dart doc.
Inside of the template.
''';

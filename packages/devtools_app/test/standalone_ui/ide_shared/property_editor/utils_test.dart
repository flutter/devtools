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

  testWidgets('convertDartDocToRichText handles plain text', (
    WidgetTester tester,
  ) async {
    final richText = convertDartDocToRichText(
      'This is a Dart doc comment.',
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    expect(richText.text.toPlainText(), equals('This is a Dart doc comment.'));
    expect(
      _hasStyle(_children(richText).first, style: regularFontStyle),
      isTrue,
    );
  });

  testWidgets('convertDartDocToRichText handles links', (
    WidgetTester tester,
  ) async {
    final richText = convertDartDocToRichText(
      'This is a [link].',
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = _children(richText);
    final firstChild = children.first;
    final secondChild = children.second;
    final thirdChild = children.third;

    expect(richText.text.toPlainText(), equals('This is a link.'));
    expect(firstChild.toPlainText(), equals('This is a '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('link'));
    expect(_hasStyle(secondChild, style: fixedFontStyle), isTrue);
    expect(thirdChild.toPlainText(), equals('.'));
    expect(_hasStyle(thirdChild, style: regularFontStyle), isTrue);
  });

  testWidgets('convertDartDocToRichText handles code blocks', (
    WidgetTester tester,
  ) async {
    final richText = convertDartDocToRichText(
      'This is `code`.',
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = _children(richText);
    final firstChild = children.first;
    final secondChild = children.second;
    final thirdChild = children.third;

    expect(richText.text.toPlainText(), equals('This is code.'));
    expect(firstChild.toPlainText(), equals('This is '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('code'));
    expect(_hasStyle(secondChild, style: fixedFontStyle), isTrue);
    expect(thirdChild.toPlainText(), equals('.'));
    expect(_hasStyle(thirdChild, style: regularFontStyle), isTrue);
  });

  testWidgets('convertDartDocToRichText handles mixed content', (
    WidgetTester tester,
  ) async {
    final richText = convertDartDocToRichText(
      'This is [a link] and `some code`.',
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = _children(richText);
    final firstChild = children.first;
    final secondChild = children.second;
    final thirdChild = children.third;
    final fourthChild = children.fourth;
    final fifthChild = children.fifth;

    expect(
      richText.text.toPlainText(),
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

  testWidgets('convertDartDocToRichText handles unmatched brackets', (
    WidgetTester tester,
  ) async {
    final richText = convertDartDocToRichText(
      'Unmatched [bracket.',
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = _children(richText);
    final firstChild = children.first;
    final secondChild = children.second;

    expect(richText.text.toPlainText(), equals('Unmatched [bracket.'));
    expect(firstChild.toPlainText(), equals('Unmatched '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('[bracket.'));
    expect(_hasStyle(secondChild, style: regularFontStyle), isTrue);
  });

  testWidgets('convertDartDocToRichText handles unmatched backticks', (
    WidgetTester tester,
  ) async {
    final richText = convertDartDocToRichText(
      'Unmatched `backtick.',
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    final children = _children(richText);
    final firstChild = children.first;
    final secondChild = children.second;

    expect(richText.text.toPlainText(), equals('Unmatched `backtick.'));
    expect(firstChild.toPlainText(), equals('Unmatched '));
    expect(_hasStyle(firstChild, style: regularFontStyle), isTrue);
    expect(secondChild.toPlainText(), equals('`backtick.'));
    expect(_hasStyle(secondChild, style: regularFontStyle), isTrue);
  });

  testWidgets('convertDartDocToRichText handles empty strings', (
    WidgetTester tester,
  ) async {
    final richText = convertDartDocToRichText(
      '',
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );

    expect(richText.text.toPlainText(), equals(''));
  });
}

List<TextSpan> _children(RichText richText) =>
    (_asTextSpan(richText.text).children ?? <InlineSpan>[])
        .map((childSpan) => _asTextSpan(childSpan))
        .toList();

bool _hasStyle(TextSpan span, {required TextStyle style}) =>
    span.style!.color == style.color;

TextSpan _asTextSpan(InlineSpan span) => span as TextSpan;

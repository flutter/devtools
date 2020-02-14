// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/flutter_widgets/tagged_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// This file is copied from package:flutter_widgets.

const TextStyle greetingStyle = TextStyle(fontWeight: FontWeight.w100);
const TextStyle nameStyle = TextStyle(fontWeight: FontWeight.w200);
const TextStyle defaultStyle = TextStyle(fontWeight: FontWeight.w500);

void main() {
  group('$TaggedText', () {
    testWidgets('without tags', (tester) async {
      const content = 'Hello, Bob';
      final widget = TaggedText(
        content: content,
        tagToTextSpanBuilder: const {},
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [const TextSpan(text: content)]);
    });

    testWidgets('with tags', (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello</greeting>, my name is <name>George</name>!',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, const [
        TextSpan(text: 'Hello', style: greetingStyle),
        TextSpan(text: ', my name is '),
        TextSpan(text: 'George', style: nameStyle),
        TextSpan(text: '!'),
      ]);
    });

    testWidgets('content tags are case insensitive', (tester) async {
      final widget = TaggedText(
        content: '<GREEting>Hello</GREEting>, my name is <nAme>George</nAme>!',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, const [
        TextSpan(text: 'Hello', style: greetingStyle),
        TextSpan(text: ', my name is '),
        TextSpan(text: 'George', style: nameStyle),
        TextSpan(text: '!'),
      ]);
    });

    testWidgets('asserts tags are not nested', (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello, my name is <name>George</name></greeting>!',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('asserts all tags in content are found', (tester) async {
      final widget = TaggedText(
        content:
            '<salutation>Hello</salutation>, my name is <name>George</name>!',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('rebuilds when content changes', (tester) async {
      final widget = TaggedText(
        content: 'Hello, Bob',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );
      await tester.pumpWidget(wrap(widget));
      final newWidget = TaggedText(
        content: 'Hello, <name>Bob</name>',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(newWidget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, const [
        TextSpan(text: 'Hello, '),
        TextSpan(text: 'Bob', style: nameStyle),
      ]);
    });

    testWidgets('rebuilds when tagToTextSpanBuilder changes', (tester) async {
      final widget = TaggedText(
        content: 'Hello, <name>Bob</name>',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );
      await tester.pumpWidget(wrap(widget));
      const updatedStyle = TextStyle(decoration: TextDecoration.overline);
      final newWidget = TaggedText(
        content: 'Hello, <name>Bob</name>',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: updatedStyle),
        },
      );

      await tester.pumpWidget(wrap(newWidget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, const [
        TextSpan(text: 'Hello, '),
        TextSpan(text: 'Bob', style: updatedStyle),
      ]);
    });

    testWidgets('does not rebuild when tagToTextSpanBuilder stays the same',
        (tester) async {
      // Set up.
      final mockTextSpanBuilder = MockTextSpanBuilder();
      const nameSpan = TextSpan(text: 'Bob', style: nameStyle);
      when(mockTextSpanBuilder.call(any)).thenReturn(nameSpan);

      const content = 'Hello, <name>Bob</name>';
      final tagToTextSpanBuilder = <String, TextSpanBuilder>{
        // TODO Eliminate this wrapper when the Dart 2 FE
        // supports mocking and tearoffs.
        'name': (x) => mockTextSpanBuilder(x),
      };
      final widget = TaggedText(
        content: content,
        tagToTextSpanBuilder: tagToTextSpanBuilder,
      );
      await tester.pumpWidget(wrap(widget));

      // Clone map to make sure that equality is checked by the contents of the
      // map.
      final newWidget = TaggedText(
        content: content,
        tagToTextSpanBuilder: Map.from(tagToTextSpanBuilder),
      );

      // Act.
      await tester.pumpWidget(wrap(newWidget));

      // Assert.
      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        const TextSpan(text: 'Hello, '),
        nameSpan,
      ]);
      verify(mockTextSpanBuilder.call(any)).called(1);
    });

    testWidgets('requires tag names to be lower case', (tester) async {
      expect(
          () => TaggedText(
                content: 'Hello, <name>Bob</name>',
                tagToTextSpanBuilder: {
                  'nAme': (text) => TextSpan(text: text, style: nameStyle),
                },
              ),
          throwsA(anything));
    });

    testWidgets('throws error when known HTML tags are used', (tester) async {
      expect(() {
        TaggedText(
          content: 'Hello, <link>Bob</link>',
          tagToTextSpanBuilder: {
            'link': (text) => TextSpan(text: text, style: nameStyle),
          },
        );
      }, throwsA(anything));
    });

    testWidgets('ignores non-elements', (tester) async {
      final widget = TaggedText(
        content: 'Hello, <!-- comment is not an element and is ignored -->'
            '<name>Bob</name>',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, const [
        TextSpan(text: 'Hello, '),
        TextSpan(text: 'Bob', style: nameStyle),
      ]);
    });

    testWidgets('renders correct input styles', (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello</greeting>',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
        },
        style: defaultStyle,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textScaleFactor: 1.5,
        maxLines: 2,
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      expect(richText.text.style, equals(defaultStyle));
      expect(richText.textAlign, equals(TextAlign.center));
      expect(richText.textDirection, equals(TextDirection.rtl));
      expect(richText.softWrap, isFalse);
      expect(richText.overflow, equals(TextOverflow.ellipsis));
      expect(richText.textScaleFactor, equals(1.5));
      expect(richText.maxLines, equals(2));
    });

    testWidgets(
        'uses 1.0 text scale factor when not specified and '
        'MediaQuery unavailable', (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello</greeting>',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
        },
        // Text scale factor not specified!
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      expect(richText.textScaleFactor, equals(1.0));
    });

    testWidgets('uses MediaQuery text scale factor when available',
        (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello</greeting>',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
        },
        // Text scale factor not specified!
      );
      const expectedTextScaleFactor = 123.4;

      await tester.pumpWidget(wrap(MediaQuery(
        data: const MediaQueryData(textScaleFactor: expectedTextScaleFactor),
        child: widget,
      )));

      final richText = findRichTextWidget(tester);
      expect(richText.textScaleFactor, equals(expectedTextScaleFactor));
    });
  });
}

RichText findRichTextWidget(WidgetTester tester) {
  final richTextFinder = find.byType(RichText);
  expect(richTextFinder, findsOneWidget);
  return tester.widget(richTextFinder) as RichText;
}

TextSpan getTextSpan(RichText richText) {
  expect(richText.text, isA<TextSpan>());
  return richText.text as TextSpan;
}

Widget wrap(Widget widget) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: widget,
  );
}

class MockTextSpanBuilder extends Mock {
  TextSpan call(String text);
}

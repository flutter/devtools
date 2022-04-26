// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/debugger/span_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const helloWorld = '''
void main() {
  print('hello world');
}
''';

const meaningOfLife = '''
void main() {
  // 42
  const int meaning = 20 + 22;

  /* print the meaning of life */
  print('The meaning of life is \$meaning, not \${meaning + 1}');
}
''';

const whileRuleApplication = '''
/// multiline
/// ```
/// doc
/// ```
/// comment
/// test
''';

const missingEnd = '''
/** there's no end to this comment
''';

const comments = '''
/*
* block comment
*/

/* inline block */

/// doc comment

// comment

/// multiline
///
/// comment

/**
 * old-school doc comment
 */
''';

const dartdoc = '''
/// [Foo] is a test class, used in the following manner:
/// ```
/// Foo.test(bar);
/// ```
''';

const punctuation = '''
,
;
.
''';

const keywords = '''
as
try
on
catch
finally
throw
rethrow
break
case
continue
default
do
else
for
if
in
return
switch
while
sync
sync*
async
async*
await
yield
yield*
assert
new
abstract
class
enum
extends
extension
external
factory
implements
get
mixin
native
operator
set
typedef
with
covariant
is
is!
?
:
<=
>>
>>>
~
^
|
&
&=
^=
|=
<<=
>>=
>>>=
=>
==
!=
<
<=
>
>=
+=
*=
/=
%=
-=
~=
=
--
++
-
+
*
/
~/
%
!
&&
||
static
final
const
required
late
void
var
''';

const openCodeBlock = '''
/// This is an open code block:
/// ```dart
///
/// This should not cause parsing to fail.

void main() {
  // But scope should end when parent scope is closed.
}
''';

void spanTester({
  required ScopeSpan span,
  required List<String> scopes,
  required int line,
  required int column,
  required int length,
}) {
  expect(span.scopes, scopes);
  expect(span.line, line);
  expect(span.column, column);
  expect(span.length, length);
}

void main() {
  late Grammar grammar;
  setUpAll(() async {
    final grammarFile = File('assets/dart_syntax.json');
    expect(grammarFile.existsSync(), true);

    final grammarJson = json.decode(await grammarFile.readAsString());
    grammar = Grammar.fromJson(grammarJson);
  });

  group('SpanParser:', () {
    test('Hello world', () {
      final spans = SpanParser.parse(grammar, helloWorld);
      expect(spans.length, 5);
      // void
      spanTester(
        span: spans[0],
        scopes: ['storage.type.primitive.dart'],
        line: 1,
        column: 1,
        length: 4,
      );

      // main
      spanTester(
        span: spans[1],
        scopes: ['entity.name.function.dart'],
        line: 1,
        column: 6,
        length: 4,
      );

      // print
      spanTester(
        span: spans[2],
        scopes: ['entity.name.function.dart'],
        line: 2,
        column: 3,
        length: 5,
      );

      // '
      spanTester(
        span: spans[3],
        scopes: ['string.interpolated.single.dart'],
        line: 2,
        column: 9,
        length: 13,
      );

      // ;
      spanTester(
        span: spans[4],
        scopes: ['punctuation.terminator.dart'],
        line: 2,
        column: 23,
        length: 1,
      );
    });

    test('Meaning of life', () {
      final spans = SpanParser.parse(grammar, meaningOfLife);

      // void
      spanTester(
        span: spans[0],
        scopes: ['storage.type.primitive.dart'],
        line: 1,
        column: 1,
        length: 4,
      );

      // main
      spanTester(
        span: spans[1],
        scopes: ['entity.name.function.dart'],
        line: 1,
        column: 6,
        length: 4,
      );

      // //
      spanTester(
        span: spans[2],
        scopes: ['comment.line.double-slash.dart'],
        line: 2,
        column: 3,
        length: 5,
      );

      // const
      spanTester(
        span: spans[3],
        scopes: ['storage.modifier.dart'],
        line: 3,
        column: 3,
        length: 5,
      );

      // int
      spanTester(
        span: spans[4],
        scopes: ['support.class.dart'],
        line: 3,
        column: 9,
        length: 3,
      );

      // =
      spanTester(
        span: spans[5],
        scopes: ['keyword.operator.assignment.dart'],
        line: 3,
        column: 21,
        length: 1,
      );

      // 20
      spanTester(
        span: spans[6],
        scopes: ['constant.numeric.dart'],
        line: 3,
        column: 23,
        length: 2,
      );

      // +
      spanTester(
        span: spans[7],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 3,
        column: 26,
        length: 1,
      );

      // 22
      spanTester(
        span: spans[8],
        scopes: ['constant.numeric.dart'],
        line: 3,
        column: 28,
        length: 2,
      );

      // ;
      spanTester(
        span: spans[9],
        scopes: ['punctuation.terminator.dart'],
        line: 3,
        column: 30,
        length: 1,
      );

      // /*
      spanTester(
        span: spans[10],
        scopes: ['comment.block.dart'],
        line: 5,
        column: 3,
        length: 31,
      );

      // print
      spanTester(
        span: spans[11],
        scopes: ['entity.name.function.dart'],
        line: 6,
        column: 3,
        length: 5,
      );

      // '
      spanTester(
        span: spans[12],
        scopes: ['string.interpolated.single.dart'],
        line: 6,
        column: 9,
        length: 53,
      );

      // $meaning
      spanTester(
        span: spans[13],
        scopes: [
          'string.interpolated.single.dart',
          'variable.parameter.dart',
        ],
        line: 6,
        column: 34,
        length: 7,
      );

      // ${meaning + 1}
      spanTester(
        span: spans[14],
        scopes: [
          'string.interpolated.single.dart',
          'variable.parameter.dart',
        ],
        line: 6,
        column: 49,
        length: 11,
      );

      // ;
      spanTester(
        span: spans[15],
        scopes: ['punctuation.terminator.dart'],
        line: 6,
        column: 63,
        length: 1,
      );
    });

    test('handles comments', () {
      final spans = SpanParser.parse(grammar, comments);
      expect(spans.length, 6);

      // /*
      // * block comment
      // */
      spanTester(
        span: spans[0],
        scopes: ['comment.block.dart'],
        line: 1,
        column: 1,
        length: 21,
      );

      // /* inline block */
      spanTester(
        span: spans[1],
        scopes: ['comment.block.dart'],
        line: 5,
        column: 1,
        length: 18,
      );

      // /// doc comment
      spanTester(
        span: spans[2],
        scopes: ['comment.block.documentation.dart'],
        line: 7,
        column: 1,
        length: 16,
      );

      // // comment
      spanTester(
        span: spans[3],
        scopes: ['comment.line.double-slash.dart'],
        line: 9,
        column: 1,
        length: 10,
      );

      // /// multiline
      // ///
      // /// comment
      spanTester(
        span: spans[4],
        scopes: ['comment.block.documentation.dart'],
        line: 11,
        column: 1,
        length: 30,
      );

      // /**
      //  * old-school doc comment
      //  */
      spanTester(
        span: spans[5],
        scopes: ['comment.block.documentation.dart'],
        line: 15,
        column: 1,
        length: 33,
      );
    });

    test('handles dartdoc', () {
      final spans = SpanParser.parse(grammar, dartdoc);

      // Covers block of lines starting with '///'
      spanTester(
        span: spans[0],
        scopes: ['comment.block.documentation.dart'],
        line: 1,
        column: 1,
        length: 92,
      );

      // [Foo]
      spanTester(
        span: spans[1],
        scopes: [
          'comment.block.documentation.dart',
          'variable.name.source.dart',
        ],
        line: 1,
        column: 5,
        length: 5,
      );

      // Whitespace after ```
      spanTester(
        span: spans[2],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 2,
        column: 8,
        length: 1,
      );

      // Foo.test(bar);
      spanTester(
        span: spans[3],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 3,
        column: 4,
        length: 16,
      );

      // Whitespace after ```
      spanTester(
        span: spans[4],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 4,
        column: 4,
        length: 1,
      );
    });

    // '///' comment blocks are parsed using a 'while' condition which looks for
    // '///' at the beginning of each line to determine whether or not the rule's
    // patterns should be applied to that line. The output of this type of match
    // should consist of a single span which includes the first '/' to the end of
    // the last line that matched the 'while' condition.
    test("handles 'while' rules", () {
      final spans = SpanParser.parse(grammar, whileRuleApplication);
      expect(spans.length, 4);

      // /// multiline
      spanTester(
        span: spans[0],
        scopes: ['comment.block.documentation.dart'],
        line: 1,
        column: 1,
        length: 59,
      );

      // \n/// doc\n///
      spanTester(
        span: spans[1],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 2,
        column: 8,
        length: 1,
      );

      spanTester(
        span: spans[2],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 3,
        column: 4,
        length: 5,
      );

      spanTester(
        span: spans[3],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 4,
        column: 4,
        length: 1,
      );
    });

    // Multiline rules allow for matching spans that do not close with a match to
    // the 'end' pattern in the case that EOF has been reached.
    test('handles EOF gracefully', () {
      final spans = SpanParser.parse(grammar, missingEnd);
      expect(spans.length, 1);
      spanTester(
        span: spans[0],
        scopes: ['comment.block.documentation.dart'],
        line: 1,
        column: 1,
        length: 35,
      );
    });

    test('keywords', () {
      final spans = SpanParser.parse(grammar, keywords);
      spanTester(
        span: spans[0],
        scopes: ['keyword.cast.dart'],
        line: 1,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[1],
        scopes: ['keyword.control.catch-exception.dart'],
        line: 2,
        column: 1,
        length: 3,
      );
      spanTester(
        span: spans[2],
        scopes: ['keyword.control.catch-exception.dart'],
        line: 3,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[3],
        scopes: ['keyword.control.catch-exception.dart'],
        line: 4,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[4],
        scopes: ['keyword.control.catch-exception.dart'],
        line: 5,
        column: 1,
        length: 7,
      );
      spanTester(
        span: spans[5],
        scopes: ['keyword.control.catch-exception.dart'],
        line: 6,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[6],
        scopes: ['keyword.control.catch-exception.dart'],
        line: 7,
        column: 1,
        length: 7,
      );
      spanTester(
        span: spans[7],
        scopes: ['keyword.control.dart'],
        line: 8,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[8],
        scopes: ['keyword.control.dart'],
        line: 9,
        column: 1,
        length: 4,
      );
      spanTester(
        span: spans[9],
        scopes: ['keyword.control.dart'],
        line: 10,
        column: 1,
        length: 8,
      );
      spanTester(
        span: spans[10],
        scopes: ['keyword.control.dart'],
        line: 11,
        column: 1,
        length: 7,
      );
      spanTester(
        span: spans[11],
        scopes: ['keyword.control.dart'],
        line: 12,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[12],
        scopes: ['keyword.control.dart'],
        line: 13,
        column: 1,
        length: 4,
      );
      spanTester(
        span: spans[13],
        scopes: ['keyword.control.dart'],
        line: 14,
        column: 1,
        length: 3,
      );
      spanTester(
        span: spans[14],
        scopes: ['keyword.control.dart'],
        line: 15,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[15],
        scopes: ['keyword.control.dart'],
        line: 16,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[16],
        scopes: ['keyword.control.dart'],
        line: 17,
        column: 1,
        length: 6,
      );
      spanTester(
        span: spans[17],
        scopes: ['keyword.control.dart'],
        line: 18,
        column: 1,
        length: 6,
      );
      spanTester(
        span: spans[18],
        scopes: ['keyword.control.dart'],
        line: 19,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[19],
        scopes: ['keyword.control.dart'],
        line: 20,
        column: 1,
        length: 4,
      );
      spanTester(
        span: spans[20],
        scopes: ['keyword.control.dart'],
        line: 21,
        column: 1,
        length: 4,
      );
      spanTester(
        span: spans[21],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 21,
        column: 5,
        length: 1,
      );
      spanTester(
        span: spans[22],
        scopes: ['keyword.control.dart'],
        line: 22,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[23],
        scopes: ['keyword.control.dart'],
        line: 23,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[24],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 23,
        column: 6,
        length: 1,
      );
      spanTester(
        span: spans[25],
        scopes: ['keyword.control.dart'],
        line: 24,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[26],
        scopes: ['keyword.control.dart'],
        line: 25,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[27],
        scopes: ['keyword.control.dart'],
        line: 26,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[28],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 26,
        column: 6,
        length: 1,
      );
      spanTester(
        span: spans[29],
        scopes: ['keyword.control.dart'],
        line: 27,
        column: 1,
        length: 6,
      );
      spanTester(
        span: spans[30],
        scopes: ['keyword.control.new.dart'],
        line: 28,
        column: 1,
        length: 3,
      );
      spanTester(
        span: spans[31],
        scopes: ['keyword.declaration.dart'],
        line: 29,
        column: 1,
        length: 8,
      );
      spanTester(
        span: spans[32],
        scopes: ['keyword.declaration.dart'],
        line: 30,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[33],
        scopes: ['keyword.declaration.dart'],
        line: 31,
        column: 1,
        length: 4,
      );
      spanTester(
        span: spans[34],
        scopes: ['keyword.declaration.dart'],
        line: 32,
        column: 1,
        length: 7,
      );
      spanTester(
        span: spans[35],
        scopes: ['keyword.declaration.dart'],
        line: 33,
        column: 1,
        length: 9,
      );
      spanTester(
        span: spans[36],
        scopes: ['keyword.declaration.dart'],
        line: 34,
        column: 1,
        length: 8,
      );
      spanTester(
        span: spans[37],
        scopes: ['keyword.declaration.dart'],
        line: 35,
        column: 1,
        length: 7,
      );
      spanTester(
        span: spans[38],
        scopes: ['keyword.declaration.dart'],
        line: 36,
        column: 1,
        length: 10,
      );
      spanTester(
        span: spans[39],
        scopes: ['keyword.declaration.dart'],
        line: 37,
        column: 1,
        length: 3,
      );
      spanTester(
        span: spans[40],
        scopes: ['keyword.declaration.dart'],
        line: 38,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[41],
        scopes: ['keyword.declaration.dart'],
        line: 39,
        column: 1,
        length: 6,
      );
      spanTester(
        span: spans[42],
        scopes: ['keyword.declaration.dart'],
        line: 40,
        column: 1,
        length: 8,
      );
      spanTester(
        span: spans[43],
        scopes: ['keyword.declaration.dart'],
        line: 41,
        column: 1,
        length: 3,
      );
      spanTester(
        span: spans[44],
        scopes: ['keyword.declaration.dart'],
        line: 42,
        column: 1,
        length: 7,
      );
      spanTester(
        span: spans[45],
        scopes: ['keyword.declaration.dart'],
        line: 43,
        column: 1,
        length: 4,
      );
      spanTester(
        span: spans[46],
        scopes: ['keyword.declaration.dart'],
        line: 44,
        column: 1,
        length: 9,
      );
      spanTester(
        span: spans[47],
        scopes: ['keyword.operator.dart'],
        line: 45,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[48],
        scopes: ['keyword.operator.dart'],
        line: 46,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[49],
        scopes: ['keyword.operator.logical.dart'],
        line: 46,
        column: 3,
        length: 1,
      );
      spanTester(
        span: spans[50],
        scopes: ['keyword.operator.ternary.dart'],
        line: 47,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[51],
        scopes: ['keyword.operator.ternary.dart'],
        line: 48,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[52],
        scopes: ['keyword.operator.comparison.dart'],
        line: 49,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[53],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 50,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[54],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 51,
        column: 1,
        length: 3,
      );
      spanTester(
        span: spans[55],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 52,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[56],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 53,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[57],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 54,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[58],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 55,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[59],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 56,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[60],
        scopes: ['keyword.operator.assignment.dart'],
        line: 56,
        column: 2,
        length: 1,
      );
      spanTester(
        span: spans[61],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 57,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[62],
        scopes: ['keyword.operator.assignment.dart'],
        line: 57,
        column: 2,
        length: 1,
      );
      spanTester(
        span: spans[63],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 58,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[64],
        scopes: ['keyword.operator.assignment.dart'],
        line: 58,
        column: 2,
        length: 1,
      );
      spanTester(
        span: spans[65],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 59,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[66],
        scopes: ['keyword.operator.assignment.dart'],
        line: 59,
        column: 3,
        length: 1,
      );
      spanTester(
        span: spans[67],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 60,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[68],
        scopes: ['keyword.operator.assignment.dart'],
        line: 60,
        column: 3,
        length: 1,
      );
      spanTester(
        span: spans[69],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 61,
        column: 1,
        length: 3,
      );
      spanTester(
        span: spans[70],
        scopes: ['keyword.operator.assignment.dart'],
        line: 61,
        column: 4,
        length: 1,
      );
      spanTester(
        span: spans[71],
        scopes: ['keyword.operator.closure.dart'],
        line: 62,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[72],
        scopes: ['keyword.operator.comparison.dart'],
        line: 63,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[73],
        scopes: ['keyword.operator.comparison.dart'],
        line: 64,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[74],
        scopes: ['keyword.operator.comparison.dart'],
        line: 65,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[75],
        scopes: ['keyword.operator.comparison.dart'],
        line: 66,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[76],
        scopes: ['keyword.operator.comparison.dart'],
        line: 67,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[77],
        scopes: ['keyword.operator.comparison.dart'],
        line: 68,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[78],
        scopes: ['keyword.operator.assignment.arithmetic.dart'],
        line: 69,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[79],
        scopes: ['keyword.operator.assignment.arithmetic.dart'],
        line: 70,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[80],
        scopes: ['keyword.operator.assignment.arithmetic.dart'],
        line: 71,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[81],
        scopes: ['keyword.operator.assignment.arithmetic.dart'],
        line: 72,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[82],
        scopes: ['keyword.operator.assignment.arithmetic.dart'],
        line: 73,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[83],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 74,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[84],
        scopes: ['keyword.operator.assignment.dart'],
        line: 74,
        column: 2,
        length: 1,
      );
      spanTester(
        span: spans[85],
        scopes: ['keyword.operator.assignment.dart'],
        line: 75,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[86],
        scopes: ['keyword.operator.increment-decrement.dart'],
        line: 76,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[87],
        scopes: ['keyword.operator.increment-decrement.dart'],
        line: 77,
        column: 1,
        length: 2,
      );
      spanTester(
        span: spans[88],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 78,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[89],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 79,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[90],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 80,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[91],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 81,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[92],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 82,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[93],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 82,
        column: 2,
        length: 1,
      );
      spanTester(
        span: spans[94],
        scopes: ['keyword.operator.arithmetic.dart'],
        line: 83,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[95],
        scopes: ['keyword.operator.logical.dart'],
        line: 84,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[96],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 85,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[97],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 85,
        column: 2,
        length: 1,
      );
      spanTester(
        span: spans[98],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 86,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[99],
        scopes: ['keyword.operator.bitwise.dart'],
        line: 86,
        column: 2,
        length: 1,
      );
      spanTester(
        span: spans[100],
        scopes: ['storage.modifier.dart'],
        line: 87,
        column: 1,
        length: 6,
      );
      spanTester(
        span: spans[101],
        scopes: ['storage.modifier.dart'],
        line: 88,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[102],
        scopes: ['storage.modifier.dart'],
        line: 89,
        column: 1,
        length: 5,
      );
      spanTester(
        span: spans[103],
        scopes: ['storage.modifier.dart'],
        line: 90,
        column: 1,
        length: 8,
      );
      spanTester(
        span: spans[104],
        scopes: ['storage.modifier.dart'],
        line: 91,
        column: 1,
        length: 4,
      );
      spanTester(
        span: spans[105],
        scopes: ['storage.type.primitive.dart'],
        line: 92,
        column: 1,
        length: 4,
      );
      spanTester(
        span: spans[106],
        scopes: ['storage.type.primitive.dart'],
        line: 93,
        column: 1,
        length: 3,
      );
    });

    test('punctuation', () {
      final spans = SpanParser.parse(grammar, punctuation);
      expect(spans.length, 3);
      spanTester(
        span: spans[0],
        scopes: ['punctuation.comma.dart'],
        line: 1,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[1],
        scopes: ['punctuation.terminator.dart'],
        line: 2,
        column: 1,
        length: 1,
      );
      spanTester(
        span: spans[2],
        scopes: ['punctuation.dot.dart'],
        line: 3,
        column: 1,
        length: 1,
      );
    });

    test('handles malformed input', () {
      final spans = SpanParser.parse(grammar, openCodeBlock);
      expect(spans.length, 7);

      // Represents the span covering all lines starting with '///'
      spanTester(
        span: spans[0],
        scopes: ['comment.block.documentation.dart'],
        line: 1,
        column: 1,
        length: 91,
      );

      // Immediately following '```dart'
      spanTester(
        span: spans[1],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 2,
        column: 12,
        length: 1,
      );

      // Whitespace after 3rd '///' line.
      spanTester(
        span: spans[2],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 3,
        column: 4,
        length: 1,
      );

      // 'This should not cause parsing to fail.'
      spanTester(
        span: spans[3],
        scopes: [
          'comment.block.documentation.dart',
          'variable.other.source.dart',
        ],
        line: 4,
        column: 4,
        length: 40,
      );

      // void
      spanTester(
        span: spans[4],
        scopes: [
          'storage.type.primitive.dart',
        ],
        line: 6,
        column: 1,
        length: 4,
      );

      // main
      spanTester(
        span: spans[5],
        scopes: [
          'entity.name.function.dart',
        ],
        line: 6,
        column: 6,
        length: 4,
      );

      // '// But scope should end when parent scope is closed.'
      spanTester(
        span: spans[6],
        scopes: [
          'comment.line.double-slash.dart',
        ],
        line: 7,
        column: 3,
        length: 52,
      );
    });
  });
}

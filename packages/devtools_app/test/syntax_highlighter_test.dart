// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/span_parser.dart';
import 'package:devtools_app/src/screens/debugger/syntax_highlighter.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/routing.dart';
import 'package:devtools_app/src/shared/theme.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const modifierSpans = [
  // Start multi-capture spans
  'import "foo";',
  'export "foo";',
  'part of "baz";',
  'part "foo";',
  'export "foo";',
  // End multi-capture spans
  '@annotation',
  'true',
  'false',
  'null',
  'as',
  'abstract',
  'class',
  'enum',
  'extends',
  'extension',
  'external',
  'factory',
  'implements',
  'get',
  'mixin',
  'native',
  'operator',
  'set',
  'typedef',
  'with',
  'covariant',
  'static',
  'final',
  'const',
  'required',
  'late',
];

const controlFlowSpans = [
  'try',
  'on',
  'catch',
  'finally',
  'throw',
  'rethrow',
  'break',
  'case',
  'continue',
  'default',
  'do',
  'else',
  'for',
  'if',
  'in',
  'return',
  'switch',
  'while',
  'sync',
  'async',
  'await',
  'yield',
  'assert',
  'new',
];

const declarationSpans = [
  'this',
  'super',
  'bool',
  'num',
  'int',
  'double',
  'dynamic',
  '_PrivateDeclaration',
  'PublicDeclaration',
];

const functionSpans = [
  'foo()',
  '_foo()',
  'foo(bar)',
];

const numericSpans = [
  '1',
  '1.1',
  '0xFF',
  '0xff',
  '1.3e5',
  '1.3E5',
];

const helloWorld = '''
Future<void> main() async {
  print('hello world!');
}
''';

const multilineDoc = '''
/**
 * Multiline
 */
''';

const docCodeReference = '''
/// This is a code reference for [Foo]
''';

const variableReferenceInString = '''
'\$i: \${foo[i] == bar[i]}'
''';

void main() {
  Grammar grammar;
  setUp(() async {
    final grammarFile = File('assets/dart_syntax.json');
    expect(grammarFile.existsSync(), true);

    final grammarJson = json.decode(await grammarFile.readAsString());
    grammar = Grammar.fromJson(grammarJson);
    setGlobal(IdeTheme, IdeTheme());
  });

  Color defaultTextColor(_) => const TextStyle().color;
  Color commentSyntaxColor(ColorScheme scheme) => scheme.commentSyntaxColor;
  Color controlFlowSyntaxColor(ColorScheme scheme) =>
      scheme.controlFlowSyntaxColor;
  Color declarationSyntaxColor(ColorScheme scheme) =>
      scheme.declarationsSyntaxColor;
  Color functionSyntaxColor(ColorScheme scheme) => scheme.functionSyntaxColor;
  Color modifierSyntaxColor(ColorScheme scheme) => scheme.modifierSyntaxColor;
  Color numericConstantSyntaxColor(ColorScheme scheme) =>
      scheme.numericConstantSyntaxColor;
  Color stringSyntaxColor(ColorScheme scheme) => scheme.stringSyntaxColor;
  Color variableSyntaxColor(ColorScheme scheme) => scheme.variableSyntaxColor;

  void spanTester(
    BuildContext context,
    TextSpan span,
    String expectedText,
    Color Function(ColorScheme) expectedColor,
  ) {
    expect(span.text, expectedText);
    expect(
      span.style,
      TextStyle(
        color: expectedColor(Theme.of(context).colorScheme),
      ),
    );
  }

  void runTestsWithTheme({@required bool useDarkTheme}) {
    group(
      'Syntax Highlighting (${useDarkTheme ? 'Dark' : 'Light'} Theme)',
      () {
        Widget buildSyntaxHighlightingTestContext(
          Function(BuildContext) callback,
        ) {
          return MaterialApp.router(
            theme: themeFor(
              isDarkTheme: useDarkTheme,
              ideTheme: getIdeTheme(),
            ),
            routerDelegate: DevToolsRouterDelegate(null),
            routeInformationParser: DevToolsRouteInformationParser(),
            builder: (context, _) {
              callback(context);
              return Container();
            },
          );
        }

        testWidgetsWithContext(
          'hello world smoke',
          (WidgetTester tester) async {
            final highlighter = SyntaxHighlighter.withGrammar(
              grammar: grammar,
              source: helloWorld,
            );

            await tester.pumpWidget(
              buildSyntaxHighlightingTestContext(
                (context) {
                  final highlighted = highlighter.highlight(context);
                  final children = highlighted.children;

                  spanTester(
                    context,
                    children[0],
                    'Future',
                    declarationSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[1],
                    '<',
                    defaultTextColor,
                  );

                  spanTester(
                    context,
                    children[2],
                    'void',
                    modifierSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[3],
                    '>',
                    defaultTextColor,
                  );

                  spanTester(
                    context,
                    children[4],
                    ' ',
                    defaultTextColor,
                  );

                  spanTester(
                    context,
                    children[5],
                    'main',
                    functionSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[6],
                    '() ',
                    defaultTextColor,
                  );

                  spanTester(
                    context,
                    children[7],
                    'async',
                    controlFlowSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[8],
                    ' {',
                    defaultTextColor,
                  );

                  expect(children[9].toPlainText(), '\n');

                  spanTester(
                    context,
                    children[10],
                    '  ',
                    defaultTextColor,
                  );

                  spanTester(
                    context,
                    children[11],
                    'print',
                    functionSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[12],
                    '(',
                    defaultTextColor,
                  );

                  spanTester(
                    context,
                    children[13],
                    "'hello world!'",
                    stringSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[14],
                    ')',
                    defaultTextColor,
                  );

                  spanTester(
                    context,
                    children[15],
                    ';',
                    defaultTextColor,
                  );

                  expect(children[16].toPlainText(), '\n');

                  spanTester(
                    context,
                    children[17],
                    '}',
                    defaultTextColor,
                  );

                  expect(children[18].toPlainText(), '\n');

                  return Container();
                },
              ),
            );
          },
        );

        testWidgetsWithContext(
          'multiline documentation',
          (WidgetTester tester) async {
            final highlighter = SyntaxHighlighter.withGrammar(
              grammar: grammar,
              source: multilineDoc,
            );

            await tester.pumpWidget(
              buildSyntaxHighlightingTestContext(
                (context) {
                  final highlighted = highlighter.highlight(context);
                  final children = highlighted.children;

                  spanTester(
                    context,
                    children[0],
                    '/**',
                    commentSyntaxColor,
                  );

                  expect(children[1].toPlainText(), '\n');

                  spanTester(
                    context,
                    children[2],
                    ' * Multiline',
                    commentSyntaxColor,
                  );

                  expect(
                    children[3].toPlainText(),
                    '\n',
                  );

                  spanTester(
                    context,
                    children[4],
                    ' */',
                    commentSyntaxColor,
                  );
                },
              ),
            );
          },
        );

        testWidgetsWithContext(
          'documentation code reference',
          (WidgetTester tester) async {
            final highlighter = SyntaxHighlighter.withGrammar(
              grammar: grammar,
              source: docCodeReference,
            );

            await tester.pumpWidget(
              buildSyntaxHighlightingTestContext(
                (context) {
                  final highlighted = highlighter.highlight(context);
                  final children = highlighted.children;

                  spanTester(
                    context,
                    children[0],
                    '/// This is a code reference for ',
                    commentSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[1],
                    '[Foo]',
                    variableSyntaxColor,
                  );

                  expect(children[2].toPlainText(), '\n');
                },
              ),
            );
          },
        );

        testWidgetsWithContext(
          'variable reference in string',
          (WidgetTester tester) async {
            final highlighter = SyntaxHighlighter.withGrammar(
              grammar: grammar,
              source: variableReferenceInString,
            );

            await tester.pumpWidget(
              buildSyntaxHighlightingTestContext(
                (context) {
                  final highlighted = highlighter.highlight(context);
                  final children = highlighted.children;

                  spanTester(
                    context,
                    children[0],
                    "'\$",
                    stringSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[1],
                    'i',
                    variableSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[2],
                    ': \${',
                    stringSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[3],
                    'foo[i] == bar[i]',
                    variableSyntaxColor,
                  );

                  spanTester(
                    context,
                    children[4],
                    '}\'',
                    stringSyntaxColor,
                  );
                },
              ),
            );
          },
        );

        void testSingleSpan(
          String name,
          String spanText,
          Color Function(ColorScheme) colorCallback,
        ) {
          testWidgetsWithContext(
            "$name '$spanText'",
            (WidgetTester tester) async {
              final highlighter = SyntaxHighlighter.withGrammar(
                grammar: grammar,
                source: spanText,
              );

              await tester.pumpWidget(
                buildSyntaxHighlightingTestContext(
                  (context) {
                    final highlighted = highlighter.highlight(context);
                    expect(
                      highlighted.children.first.style,
                      TextStyle(
                        color: colorCallback(Theme.of(context).colorScheme),
                      ),
                    );
                    return Container();
                  },
                ),
              );
            },
          );
        }

        group(
          'single span highlighting:',
          () {
            for (final spanText in modifierSpans) {
              testSingleSpan(
                'modifier',
                spanText,
                modifierSyntaxColor,
              );
            }

            for (final spanText in controlFlowSpans) {
              testSingleSpan(
                'control flow',
                spanText,
                controlFlowSyntaxColor,
              );
            }

            for (final spanText in declarationSpans) {
              testSingleSpan(
                'declaration',
                spanText,
                declarationSyntaxColor,
              );
            }

            for (final spanText in functionSpans) {
              testSingleSpan(
                'function',
                spanText,
                functionSyntaxColor,
              );
            }

            for (final spanText in numericSpans) {
              testSingleSpan(
                'numeric',
                spanText,
                numericConstantSyntaxColor,
              );
            }
          },
        );
      },
    );
  }

  runTestsWithTheme(useDarkTheme: false);
  runTestsWithTheme(useDarkTheme: true);
}

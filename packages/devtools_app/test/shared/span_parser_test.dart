// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:devtools_app/src/screens/debugger/span_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

const missingEnd = '''
/** there's no end to this comment
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
  final updateGoldens = autoUpdateGoldenFiles;

  final Directory goldenDirectory =
      Directory(path.join('test', 'test_data', 'syntax_highlighting')).absolute;
  final grammarFile = File(path.join('assets', 'dart_syntax.json')).absolute;
  late Grammar grammar;
  setUpAll(() async {
    expect(grammarFile.existsSync(), true);
    final grammarJson = json.decode(await grammarFile.readAsString());
    grammar = Grammar.fromJson(grammarJson);
  });

  group('SpanParser', () {
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

    group('golden', () {
      // Perform golden tests on the test_data/syntax_highlighting folder.
      // These goldens are updated using the usual Flutter --update-goldens
      // flag:
      //
      //     flutter test test/shared/span_parser_test.dart --update-goldens
      final testFiles = goldenDirectory
          .listSync()
          .whereType<File>()
          .where((file) => path.extension(file.path) == '.dart');

      for (final testFile in testFiles) {
        final goldenFile = File('${testFile.path}.golden');
        test(path.basename(testFile.path), () {
          if (!goldenFile.existsSync() && !updateGoldens) {
            fail('Missing golden file: ${goldenFile.path}');
          }

          final content = testFile.readAsStringSync();
          final spans = SpanParser.parse(grammar, content);
          final actual = _buildGoldenText(content, spans);

          if (updateGoldens) {
            goldenFile.writeAsStringSync(actual);
          } else {
            final expected = goldenFile.readAsStringSync();
            expect(_normalize(actual), _normalize(expected));
          }
        });
      }
    });
  });
}

String _buildGoldenText(String content, List<ScopeSpan> spans) {
  final buffer = StringBuffer();
  final spansByLine = groupBy(spans, (ScopeSpan s) => s.line! - 1);

  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // We need the line length to wrap. If this isn't the last line, account for
    // the \n we split by.
    final lineLength = line.length + (i == lines.length - 1 ? 0 : 1);

    buffer.writeln('>$line');
    final lineSpans = spansByLine[i];
    if (lineSpans != null) {
      for (final span in lineSpans) {
        final col = span.column! - 1;
        var length = span.length;

        // Spans may roll over onto the next line, so truncate them and insert
        // the remainder into the next.
        if (col + length > lineLength) {
          final thisLineLength = lineLength - col;
          length = thisLineLength;
          spansByLine[i + 1] ??= [];
          spansByLine[i + 1]!.add(
            ScopeSpan.copy(
              scopes: span.scopes,
              start: span.start + thisLineLength,
              end: span.end,
              line: span.line! + 1,
              column: 0,
            ),
          );
        }

        buffer.write('#');
        buffer.write(' ' * col);
        buffer.write('^' * length);
        buffer.write(' ');
        buffer.writeln(span.scopes!.join(' '));
      }
    }
  }

  return buffer.toString();
}

/// Normalises newlines in code for comparing.
String _normalize(String code) => code.replaceAll('\r', '');

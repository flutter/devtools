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

void main() {
  final grammarFile = File(path.join('assets', 'dart_syntax.json')).absolute;
  late Grammar grammar;

  final Directory testDataDirectory =
      Directory(path.join('test', 'test_data', 'syntax_highlighting')).absolute;
  final Directory goldenDirectory =
      Directory(path.join('test', 'goldens', 'syntax_highlighting')).absolute;

  setUpAll(() async {
    expect(grammarFile.existsSync(), true);
    final grammarJson = json.decode(await grammarFile.readAsString());
    grammar = Grammar.fromJson(grammarJson);
  });

  group('SpanParser', () {
    final updateGoldens = autoUpdateGoldenFiles;

    /// Expects parsing [content] using produces the output in [goldenFile].
    void expectSpansMatchGolden(
      String content,
      List<ScopeSpan> spans,
      File goldenFile,
    ) {
      if (!goldenFile.existsSync() && !updateGoldens) {
        fail('Missing golden file: ${goldenFile.path}');
      }

      final actual = _buildGoldenText(content, spans);
      if (updateGoldens) {
        goldenFile.writeAsStringSync(actual);
      } else {
        final expected = goldenFile.readAsStringSync();
        expect(_normalize(actual), _normalize(expected));
      }
    }

    File goldenFileFor(String name) {
      final goldenPath = path.join(goldenDirectory.path, '$name.golden');
      return File(goldenPath);
    }

    // Multiline rules allow for matching spans that do not close with a match to
    // the 'end' pattern in the case that EOF has been reached.
    test('handles EOF gracefully', () {
      final goldenFile = goldenFileFor('handles_eof_gracefully');
      final spans = SpanParser.parse(grammar, missingEnd);
      expectSpansMatchGolden(missingEnd, spans, goldenFile);

      // Check the span ends where expected.
      final span = spans.single;
      expect(span.scopes, ['comment.block.documentation.dart']);
      expect(span.line, 1);
      expect(span.column, 1);
      expect(span.length, 35);
    });

    test('handles malformed input', () {
      final goldenFile = goldenFileFor('open_code_block');
      final spans = SpanParser.parse(grammar, openCodeBlock);
      expectSpansMatchGolden(openCodeBlock, spans, goldenFile);
    });

    group('golden', () {
      // Perform golden tests on the test_data/syntax_highlighting folder.
      // These goldens are updated using the usual Flutter --update-goldens
      // flag:
      //
      //     flutter test test/shared/span_parser_test.dart --update-goldens
      final testFiles = testDataDirectory
          .listSync()
          .whereType<File>()
          .where((file) => path.extension(file.path) == '.dart');

      for (final testFile in testFiles) {
        final goldenFile = goldenFileFor(path.basename(testFile.path));
        test(path.basename(testFile.path), () {
          final content = testFile.readAsStringSync();
          final spans = SpanParser.parse(grammar, content);

          expectSpansMatchGolden(content, spans, goldenFile);
        });
      }
    });
  });
}

String _buildGoldenText(String content, List<ScopeSpan> spans) {
  final buffer = StringBuffer();
  final spansByLine = groupBy(spans, (ScopeSpan s) => s.line - 1);

  final lines = content.trim().split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // We need the line length to wrap. If this isn't the last line, account for
    // the \n we split by.
    final newlineLength = (i == lines.length - 1) ? 0 : 1;
    final lineLengthWithNewline = line.length + newlineLength;

    buffer.writeln('>$line');
    final lineSpans = spansByLine[i];
    if (lineSpans != null) {
      for (final span in lineSpans) {
        final col = span.column - 1;
        var length = span.length;

        // Spans may roll over onto the next line, so truncate them and insert
        // the remainder into the next.
        if (col + length > lineLengthWithNewline) {
          final thisLineLength = line.length - col;
          final offsetToStartOfNextLine = lineLengthWithNewline - col;
          length = thisLineLength;
          spansByLine[i + 1] ??= [];
          // Insert the wrapped span before other spans on the next line so the
          // order is preserved.
          spansByLine[i + 1]!.insert(
            0,
            ScopeSpan(
              scopes: span.scopes,
              startLocation: ScopeStackLocation(
                position: span.start + offsetToStartOfNextLine,
                line: span.line + 1,
                column: 0,
              ),
              endLocation: span.endLocation,
            ),
          );
        } else if (col + length > line.length) {
          // Truncate any spans that include the trailing newline.
          length = line.length - col;
        }

        // If this span just covers the trailing newline, skip it
        // as it doesn't produce any useful output.
        if (col == line.length) {
          continue;
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

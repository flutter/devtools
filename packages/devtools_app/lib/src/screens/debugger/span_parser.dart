// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:string_scanner/string_scanner.dart';

// ignore: avoid_classes_with_only_static_members
abstract class SpanParser {
  /// Takes a TextMate [Grammar] and a [String] and outputs a list of
  /// [ScopeSpan]s corresponding to the parsed input.
  static List<ScopeSpan> parse(Grammar grammar, String src) {
    final scanner = LineScanner(src);
    final spans = <ScopeSpan>[];
    while (!scanner.isDone) {
      bool foundMatch = false;
      for (final pattern in grammar.topLevelMatchers!) {
        final result = pattern.scan(grammar, scanner);
        if (result != null) {
          spans.addAll(result);
          foundMatch = true;
          break;
        }
      }
      if (!foundMatch && !scanner.isDone) {
        // Found no match, move forward by a character and try again.
        scanner.readChar();
      }
    }
    return spans;
  }
}

/// A representation of a TextMate grammar used to create [ScopeSpan]s
/// representing scopes within a body of text.
///
/// References used:
///   - Grammar specification:
///       https://macromates.com/manual/en/language_grammars#language_grammars
///   - Helpful blog post which clears up ambiguities in the spec:
///       https://www.apeth.com/nonblog/stories/textmatebundle.html
///
class Grammar {
  factory Grammar.fromJson(Map<String, dynamic> json) {
    return Grammar._(
      name: json['name'],
      scopeName: json['scopeName'],
      topLevelMatchers: json['patterns']
          ?.cast<Map<String, dynamic>>()
          ?.map((e) => _Matcher.parse(e))
          ?.toList()
          ?.cast<_Matcher>(),
      repository: Repository.build(json),
    );
  }

  Grammar._({
    this.name,
    this.scopeName,
    this.topLevelMatchers,
    this.repository,
  });

  final String? name;

  final String? scopeName;

  final List<_Matcher>? topLevelMatchers;

  final Repository? repository;

  @override
  String toString() {
    return const JsonEncoder.withIndent('  ').convert({
      'name': name,
      'scopeName': scopeName,
      'patterns': topLevelMatchers!.map((e) => e.toJson()).toList(),
      'repository': repository!.toJson(),
    });
  }
}

/// A representation of a span of text which has `scope` applied to it.
class ScopeSpan {
  ScopeSpan({String? scope, int? start, int? end, this.line, this.column})
      : scopes = [
          ..._scopeStack.toList(),
          if (scope != null) scope,
        ],
        _start = start,
        _end = end;

  ScopeSpan.copy({
    this.scopes,
    int? start,
    int? end,
    this.line,
    this.column,
  })  : _start = start,
        _end = end;

  /// Adds [matcher.name] to the scope stack, if non-null. This scope will be
  /// included in each [ScopeSpan] created within [callback].
  static List<ScopeSpan> applyScope(
    _Matcher matcher,
    List<ScopeSpan> Function() callback,
  ) {
    if (matcher.name != null) {
      _scopeStack.addLast(matcher.name);
    }
    final result = callback();

    if (matcher.name != null) {
      _scopeStack.removeLast();
    }
    return result;
  }

  static final ListQueue<String?> _scopeStack = ListQueue<String?>();

  int get length => _end! - _start!;

  final int? _start;

  int? _end;

  final int? line;

  final int? column;

  final List<String?>? scopes;

  bool contains(int token) => (_start! <= token) && (token < _end!);

  /// Splits the current [ScopeSpan] into multiple spans separated by [cond].
  /// This is useful for post-processing the results from a rule with a while
  /// condition as formatting should not be applied to the characters that
  /// match the while condition.
  List<ScopeSpan> split(LineScanner scanner, RegExp cond) {
    final splitSpans = <ScopeSpan>[];

    // Create a temporary scanner, copying [0, _end] to ensure that line/column
    // information is consistent with the original scanner.
    final splitScanner = LineScanner(
      scanner.substring(0, _end),
      position: _start,
    );

    // Start with a copy of the original span
    ScopeSpan current = ScopeSpan.copy(
      scopes: scopes!.toList(),
      start: _start,
      end: _end,
      line: line,
      column: column,
    );

    while (!splitScanner.isDone) {
      if (splitScanner.matches(cond)) {
        // Update the end position for this span as it's been fully processed.
        current._end = splitScanner.position;
        splitSpans.add(current);

        // Move the scanner position past the matched condition.
        splitScanner.scan(cond);

        // Create a new span based on the current position.
        current = ScopeSpan.copy(
          scopes: scopes!.toList(),
          start: splitScanner.position,
          end: -1, // Updated later.
          // Lines and columns are 0-based.
          line: splitScanner.line + 1,
          column: splitScanner.column + 1,
        );
      } else {
        // Move scanner position forward.
        splitScanner.readChar();
      }
    }
    // Finish processing the last span, which will always have the same end
    // position as the span we're splitting.
    current._end = _end;
    splitSpans.add(current);

    return splitSpans;
  }

  @override
  String toString() {
    return '[$_start, $_end, $line:$column (len: $length)] = $scopes';
  }
}

/// A top-level repository of rules that can be referenced within other rules
/// using the 'includes' keyword.
class Repository {
  Repository.build(Map<String, dynamic> grammarJson) {
    final repositoryJson = grammarJson['repository'].cast<String, dynamic>();
    if (repositoryJson == null) {
      return;
    }
    for (final subRepo in repositoryJson.keys) {
      patterns[subRepo] = <_Matcher>[
        for (final pattern
            in repositoryJson[subRepo]['patterns'].cast<Map<String, dynamic>>())
          _Matcher.parse(pattern),
      ];
    }
  }

  final patterns = <String?, List<_Matcher>>{};

  Map<String, dynamic> toJson() {
    return {
      for (final entry in patterns.entries)
        if (entry.key != null)
          entry.key!: entry.value.map((e) => e.toJson()).toList(),
    };
  }
}

abstract class _Matcher {
  factory _Matcher.parse(Map<String, dynamic> json) {
    if (_IncludeMatcher.isType(json)) {
      return _IncludeMatcher(json['include']);
    } else if (_SimpleMatcher.isType(json)) {
      return _SimpleMatcher(json);
    } else if (_MultilineMatcher.isType(json)) {
      return _MultilineMatcher(json);
    }
    throw StateError('Unknown pattern type: $json');
  }

  _Matcher._(Map<String, dynamic> json) : name = json['name'];

  final String? name;

  List<ScopeSpan>? scan(Grammar grammar, LineScanner scanner);

  List<ScopeSpan> _applyCapture(
    LineScanner scanner,
    Map<String, dynamic>? captures,
    int line,
    int column,
  ) {
    final spans = <ScopeSpan>[];
    final start = scanner.lastMatch!.start;
    final end = scanner.lastMatch!.end;
    if (captures != null) {
      if (scanner.lastMatch!.groupCount <= 1) {
        spans.add(
          ScopeSpan(
            scope: captures['0']['name'],
            start: start,
            end: end,
            // Lines and columns are 0 indexed.
            line: line + 1,
            column: column + 1,
          ),
        );
      } else {
        final match = scanner.substring(start, end);
        for (int i = 1; i <= scanner.lastMatch!.groupCount; ++i) {
          if (captures.containsKey(i.toString())) {
            final capture = scanner.lastMatch!.group(i);
            if (capture == null) {
              continue;
            }
            final startOffset = match.indexOf(capture);
            spans.add(
              ScopeSpan(
                scope: captures[i.toString()]['name'],
                start: start + startOffset,
                end: start + startOffset + capture.length,
                // Lines and columns are 0 indexed.
                line: line + 1,
                column: column + startOffset + 1,
              ),
            );
          }
        }
      }
    } else {
      // Don't include the scope name here if we're not applying captures. This
      // is already included in the scope stack.
      spans.add(
        ScopeSpan(
          start: start,
          end: end,
          // Lines and columns are 0 indexed.
          line: line + 1,
          column: column + 1,
        ),
      );
    }
    return spans;
  }

  Map<String, dynamic> toJson();
}

/// A simple matcher which matches a single line.
class _SimpleMatcher extends _Matcher {
  _SimpleMatcher(Map<String, dynamic> json)
      : match = RegExp(json['match'], multiLine: true),
        captures = json['captures'],
        super._(json);

  static bool isType(Map<String, dynamic> json) {
    return json.containsKey('match');
  }

  final RegExp match;

  final Map<String, dynamic>? captures;

  @override
  List<ScopeSpan>? scan(Grammar grammar, LineScanner scanner) {
    final line = scanner.line;
    final column = scanner.column;
    if (scanner.scan(match)) {
      final result = ScopeSpan.applyScope(
        this,
        () => _applyCapture(scanner, captures, line, column),
      );
      return result;
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'match': match.pattern,
      if (captures != null) 'captures': captures,
    };
  }
}

class _MultilineMatcher extends _Matcher {
  _MultilineMatcher(Map<String, dynamic> json)
      : begin = RegExp(json['begin'], multiLine: true),
        beginCaptures = json['beginCaptures'],
        contentName = json['contentName'],
        end = json['end'] == null ? null : RegExp(json['end'], multiLine: true),
        endCaptures = json['endCaptures'],
        captures = json['captures'],
        whileCond = json['while'] == null
            ? null
            : RegExp(json['while'], multiLine: true),
        patterns = json['patterns']
            ?.cast<Map<String, dynamic>>()
            ?.map((e) => _Matcher.parse(e))
            ?.toList()
            ?.cast<_Matcher>(),
        super._(json);

  static bool isType(Map<String, dynamic> json) {
    return json.containsKey('begin') &&
        (json.containsKey('end') || json.containsKey('while'));
  }

  /// A regular expression which defines the beginning match of this rule. This
  /// property is required and must be defined along with either `end` or
  /// `while`.
  final RegExp begin;

  /// A set of scopes to apply to groups captured by `begin`. `captures` should
  /// be null if this property is provided.
  final Map<String, dynamic>? beginCaptures;

  /// The scope that applies to the content between the matches found by
  /// `begin` and `end`.
  final String? contentName;

  /// A regular expression which defines the match signaling the end of the
  /// rule application. This property is mutually exclusive with the `while`
  /// property.
  final RegExp? end;

  /// A set of scopes to apply to groups captured by `begin`. `captures` should
  /// be null if this property is provided.
  final Map<String, dynamic>? endCaptures;

  /// A regular expression corresponding with the `while` property used to
  /// determine if the next line should have the current rule applied. If
  /// `patterns` is provided, the contents of a line that satisfy this regular
  /// expression will be processed against the provided patterns.
  ///
  /// This expression is applied to every line **after** the first line matched
  /// by `begin`. If this expression fails after the line matched by `begin`,
  /// the overall rule does not fail and the resulting [ScopeSpan]s will consist
  /// of matches found in the first line.
  ///
  /// This property is mutually exclusive with the `end` property.
  final RegExp? whileCond;

  /// A set of scopes to apply to groups captured by `begin` and `end`.
  /// Providing this property is the equivalent of setting `beginCaptures` and
  /// `endCaptures` to the same value. `beginCaptures` and `endCaptures` should
  /// be null if this property is provided.
  final Map<String, dynamic>? captures;

  final List<_Matcher>? patterns;

  List<ScopeSpan> _scanBegin(LineScanner scanner) {
    final line = scanner.line;
    final column = scanner.column;
    if (!scanner.scan(begin)) {
      // This shouldn't happen since we've already checked that `begin` matches
      // the beginning of the string.
      throw StateError('Expected ${begin.pattern} to match.');
    }
    return _processCaptureHelper(scanner, beginCaptures, line, column);
  }

  List<ScopeSpan> _scanToEndOfLine(Grammar grammar, LineScanner scanner) {
    final results = <ScopeSpan>[];
    while (!scanner.isDone) {
      if (String.fromCharCode(scanner.peekChar()!) == '\n') {
        scanner.readChar();
        break;
      }
      bool foundMatch = false;
      for (final pattern in patterns!) {
        final result = pattern.scan(grammar, scanner);
        if (result != null) {
          results.addAll(result);
          foundMatch = true;
          break;
        }
      }
      if (!foundMatch) {
        scanner.readChar();
      }
    }
    return results;
  }

  List<ScopeSpan> _scanUpToEndMatch(Grammar grammar, LineScanner scanner) {
    final results = <ScopeSpan>[];
    while (!scanner.isDone && !scanner.matches(end!)) {
      bool foundMatch = false;
      if (patterns != null) {
        for (final pattern in patterns!) {
          final result = pattern.scan(grammar, scanner);
          if (result != null) {
            results.addAll(result);
            foundMatch = true;
            break;
          }
        }
      }
      if (!foundMatch) {
        // Move forward by a character, try again.
        scanner.readChar();
      }
    }
    return results;
  }

  List<ScopeSpan>? _scanEnd(LineScanner scanner) {
    final line = scanner.line;
    final column = scanner.column;
    if (!scanner.scan(end!)) {
      return null;
    }
    return _processCaptureHelper(scanner, beginCaptures, line, column);
  }

  List<ScopeSpan> _processCaptureHelper(
    LineScanner scanner,
    Map<String, dynamic>? customCaptures,
    int line,
    int column,
  ) {
    if (contentName == null || (customCaptures ?? captures) != null) {
      return _applyCapture(scanner, customCaptures ?? captures, line, column);
    } else {
      // If there's no explicit captures and contentName is provided, don't
      // create a span for the match.
      return [];
    }
  }

  @override
  List<ScopeSpan>? scan(Grammar grammar, LineScanner scanner) {
    if (!scanner.matches(begin)) {
      return null;
    }
    return ScopeSpan.applyScope(this, () {
      final beginSpans = _scanBegin(scanner);
      final results = <ScopeSpan>[
        if (contentName == null) ...beginSpans,
      ];
      if (end != null) {
        // If contentName is provided, the scope is applied to the contents
        // between the begin/end matches, not the matches themselves.
        if (contentName != null) {
          // Lines and columns are 0 indexed.
          final line = scanner.line + 1;
          final column = scanner.column + 1;
          final start = scanner.position;
          // TODO(bkonyi): this method tries to parse the contents to find
          // additional spans even though we'll just ignore them. Consider
          // disabling this for cases where we only care about moving the
          // scanner forward.
          _scanUpToEndMatch(grammar, scanner);
          results.add(
            ScopeSpan(
              scope: contentName,
              column: column,
              line: line,
              start: start,
              end: scanner.position,
            ),
          );
        } else {
          results.addAll(_scanUpToEndMatch(grammar, scanner));
        }
        final endSpans = _scanEnd(scanner);

        // If beginSpans is not empty and there's no captures specified, there
        // will only be a single span with a scope that covers [beginMatch.start,
        // endMatch.end).
        if (beginSpans.isNotEmpty &&
            (captures ?? endCaptures ?? beginCaptures) == null) {
          assert(beginSpans.length == 1);
          beginSpans.first._end = scanner.position;
        } else if (endSpans != null) {
          // endSpans can be null if we reach EOF and haven't completed a match.
          results.addAll(endSpans);
        }
        return results;
      } else if (whileCond != null) {
        // Find the range of the string that is matched by the while condition.
        final start = scanner.position;
        _skipLine(scanner);
        while (!scanner.isDone && scanner.scan(whileCond!)) {
          _skipLine(scanner);
        }
        final end = scanner.position;

        // Create a temporary scanner to ensure that rules that don't find an
        // end match don't try and match all the way to the end of the file.
        final contentScanner = LineScanner(
          scanner.substring(0, end),
          position: start,
        );

        final contentResults = <ScopeSpan>[];
        // Finish scanning the line matched by `begin`.
        contentResults.addAll(_scanToEndOfLine(grammar, contentScanner));

        // Process each line until the `while` condition fails.
        while (!contentScanner.isDone && contentScanner.scan(whileCond!)) {
          contentResults.addAll(_scanToEndOfLine(grammar, contentScanner));
        }

        // Split the results on the while condition to ensure that formatting
        // isn't applied to characters matching the loop condition (e.g.,
        // comment blocks with inline code samples shouldn't apply inline code
        // formatting to the leading '///').
        results.addAll(
          contentResults.expand(
            (e) => e.split(scanner, whileCond!),
          ),
        );

        if (beginSpans.isNotEmpty) {
          assert(beginSpans.length == 1);
          beginSpans.first._end = end;
        }
        return results;
      } else {
        throw StateError(
          "One of 'end' or 'while' must be provided for rule: $name",
        );
      }
    });
  }

  void _skipLine(LineScanner scanner) {
    scanner.scan(RegExp('.*\n'));
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'begin': begin.pattern,
      if (beginCaptures != null) 'beginCaptures': beginCaptures,
      if (end != null) 'end': end!.pattern,
      if (endCaptures != null) 'endCaptures': endCaptures,
      if (whileCond != null) 'while': whileCond!.pattern,
      if (patterns != null)
        'patterns': patterns!.map((e) => e.toJson()).toList(),
    };
  }
}

/// A [_Matcher] that corresponds to an `include` rule referenced in a
/// `patterns` array. Allows for executing rules defined within a
/// [Repository].
class _IncludeMatcher extends _Matcher {
  _IncludeMatcher(String include)
      : include = include.substring(1),
        super._({});

  final String include;

  static bool isType(Map<String, dynamic> json) {
    return json.containsKey('include');
  }

  @override
  List<ScopeSpan>? scan(Grammar grammar, LineScanner scanner) {
    final patterns = grammar.repository!.patterns[include];
    if (patterns == null) {
      throw StateError('Could not find $include in the repository.');
    }
    // Try each rule in the include and return the result from the first
    // successful match.
    for (final pattern in patterns) {
      final result = pattern.scan(grammar, scanner);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'include': include,
    };
  }
}

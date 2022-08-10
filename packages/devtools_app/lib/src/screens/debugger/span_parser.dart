// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:string_scanner/string_scanner.dart';

// ignore: avoid_classes_with_only_static_members
abstract class SpanParser {
  /// Takes a TextMate [Grammar] and a [String] and outputs a list of
  /// [ScopeSpan]s corresponding to the parsed input.
  static List<ScopeSpan> parse(Grammar grammar, String src) {
    final scopeStack = ScopeStack();
    final scanner = LineScanner(src);
    while (!scanner.isDone) {
      bool foundMatch = false;
      for (final pattern in grammar.topLevelMatchers!) {
        if (pattern.scan(grammar, scanner, scopeStack)) {
          foundMatch = true;
          break;
        }
      }
      if (!foundMatch && !scanner.isDone) {
        // Found no match, move forward by a character and try again.
        scanner.readChar();
      }
    }
    scopeStack.popAll(scanner.location);
    return scopeStack.spans;
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
  ScopeSpan({
    required this.scopes,
    required ScopeStackLocation startLocation,
    required ScopeStackLocation endLocation,
  })  : _startLocation = startLocation,
        _endLocation = endLocation;

  ScopeStackLocation get startLocation => _startLocation;
  ScopeStackLocation get endLocation => _endLocation;
  int get start => _startLocation.position;
  int get end => _endLocation.position;
  int get length => end - start;

  final ScopeStackLocation _startLocation;
  ScopeStackLocation _endLocation;

  /// The one-based line number.
  int get line => startLocation.line + 1;

  /// The one-based column number.
  int get column => startLocation.column + 1;

  final List<String?> scopes;

  bool contains(int token) => (start <= token) && (token < end);

  /// Splits the current [ScopeSpan] into multiple spans separated by [cond].
  /// This is useful for post-processing the results from a rule with a while
  /// condition as formatting should not be applied to the characters that
  /// match the while condition.
  List<ScopeSpan> split(LineScanner scanner, RegExp cond) {
    final splitSpans = <ScopeSpan>[];

    // Create a temporary scanner, copying [0, end] to ensure that line/column
    // information is consistent with the original scanner.
    final splitScanner = LineScanner(
      scanner.substring(0, end),
      position: start,
    );

    // Start with a copy of the original span
    ScopeSpan current = ScopeSpan(
      scopes: scopes.toList(),
      startLocation: startLocation,
      endLocation: endLocation,
    );

    while (!splitScanner.isDone) {
      if (splitScanner.matches(cond)) {
        // Update the end position for this span as it's been fully processed.
        current._endLocation = splitScanner.location;
        splitSpans.add(current);

        // Move the scanner position past the matched condition.
        splitScanner.scan(cond);

        // Create a new span based on the current position.
        current = ScopeSpan(
          scopes: scopes.toList(),
          startLocation: splitScanner.location,
          // Will be updated later.
          endLocation: ScopeStackLocation.zero,
        );
      } else {
        // Move scanner position forward.
        splitScanner.readChar();
      }
    }
    // Finish processing the last span, which will always have the same end
    // position as the span we're splitting.
    current._endLocation = endLocation;
    splitSpans.add(current);

    return splitSpans;
  }

  @override
  String toString() {
    return '[$start, $end, $line:$column (len: $length)] = $scopes';
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

  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack);

  List<ScopeSpan> _applyCapture(
    LineScanner scanner,
    ScopeStack scopeStack,
    Map<String, dynamic>? captures,
    ScopeStackLocation location,
  ) {
    final spans = <ScopeSpan>[];
    final lastMatch = scanner.lastMatch!;
    final start = lastMatch.start;
    final end = lastMatch.end;
    final matchStartLocation = location;
    final matchEndLocation = scanner.location;
    if (captures != null) {
      if (lastMatch.groupCount <= 1) {
        scopeStack.add(
          captures['0']['name'],
          start: matchStartLocation,
          end: matchEndLocation,
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
            scopeStack.add(
              captures[i.toString()]['name'],
              start: matchStartLocation.offset(startOffset),
              end: matchStartLocation.offset(startOffset + capture.length),
            );
          }
        }
      }
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
  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    final location = scanner.location;
    if (scanner.scan(match)) {
      scopeStack.push(name, location);
      _applyCapture(scanner, scopeStack, captures, location);
      scopeStack.pop(name, scanner.location);
      return true;
    }
    return false;
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

  void _scanBegin(LineScanner scanner, ScopeStack scopeStack) {
    final location = scanner.location;
    if (!scanner.scan(begin)) {
      // This shouldn't happen since we've already checked that `begin` matches
      // the beginning of the string.
      throw StateError('Expected ${begin.pattern} to match.');
    }
    _processCaptureHelper(scanner, scopeStack, beginCaptures, location);
  }

  void _scanToEndOfLine(
    Grammar grammar,
    LineScanner scanner,
    ScopeStack scopeStack,
  ) {
    while (!scanner.isDone) {
      if (String.fromCharCode(scanner.peekChar()!) == '\n') {
        scanner.readChar();
        break;
      }
      bool foundMatch = false;
      for (final pattern in patterns ?? <_Matcher>[]) {
        if (pattern.scan(grammar, scanner, scopeStack)) {
          foundMatch = true;
          break;
        }
      }
      if (!foundMatch) {
        scanner.readChar();
      }
    }
  }

  void _scanUpToEndMatch(
    Grammar grammar,
    LineScanner scanner,
    ScopeStack scopeStack,
  ) {
    while (!scanner.isDone && end != null && !scanner.matches(end!)) {
      bool foundMatch = false;
      for (final pattern in patterns ?? <_Matcher>[]) {
        if (pattern.scan(grammar, scanner, scopeStack)) {
          foundMatch = true;
          break;
        }
      }
      if (!foundMatch) {
        // Move forward by a character, try again.
        scanner.readChar();
      }
    }
  }

  void _scanEnd(LineScanner scanner, ScopeStack scopeStack) {
    final location = scanner.location;
    if (end != null && !scanner.scan(end!)) {
      return null;
    }
    _processCaptureHelper(scanner, scopeStack, endCaptures, location);
  }

  void _processCaptureHelper(
    LineScanner scanner,
    ScopeStack scopeStack,
    Map<String, dynamic>? customCaptures,
    ScopeStackLocation location,
  ) {
    if (contentName == null || (customCaptures ?? captures) != null) {
      _applyCapture(scanner, scopeStack, customCaptures ?? captures, location);
    }
  }

  @override
  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    if (!scanner.matches(begin)) {
      return false;
    }

    scopeStack.push(name, scanner.location);
    _scanBegin(scanner, scopeStack);
    if (end != null) {
      scopeStack.push(contentName, scanner.location);
      _scanUpToEndMatch(grammar, scanner, scopeStack);
      scopeStack.pop(contentName, scanner.location);
      _scanEnd(scanner, scopeStack);
    } else if (whileCond != null) {
      // Find the range of the string that is matched by the while condition.
      final start = scanner.position;
      _skipLine(scanner);
      while (!scanner.isDone && whileCond != null && scanner.scan(whileCond!)) {
        _skipLine(scanner);
      }
      final end = scanner.position;

      // Create a temporary scanner to ensure that rules that don't find an
      // end match don't try and match all the way to the end of the file.
      final contentScanner = LineScanner(
        scanner.substring(0, end),
        position: start,
      );

      // Capture a marker for where the contents start, used later to split
      // spans.
      final whileContentBeginMarker = scopeStack.marker();

      _scanToEndOfLine(grammar, contentScanner, scopeStack);

      // Process each line until the `while` condition fails.
      while (!contentScanner.isDone &&
          whileCond != null &&
          contentScanner.scan(whileCond!)) {
        _scanToEndOfLine(grammar, contentScanner, scopeStack);
      }

      // Now, split any spans produced whileContentBeginMarker by `whileCond`.
      scopeStack.splitFromMarker(
        scanner,
        whileContentBeginMarker,
        whileCond!,
      );
    } else {
      throw StateError(
        "One of 'end' or 'while' must be provided for rule: $name",
      );
    }
    scopeStack.pop(name, scanner.location);
    return true;
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
  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    final patterns = grammar.repository?.patterns[include];
    if (patterns == null) {
      throw StateError('Could not find $include in the repository.');
    }
    // Try each rule in the include until one matches.
    for (final pattern in patterns) {
      if (pattern.scan(grammar, scanner, scopeStack)) {
        return true;
      }
    }
    return false;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'include': include,
    };
  }
}

/// Tracks the current scope stack, producing [ScopeSpan]s as the contents
/// change.
class ScopeStack {
  ScopeStack();

  final Queue<ScopeStackItem> stack = Queue();
  final List<ScopeSpan> spans = [];

  /// Location where the next produced span should begin.
  ScopeStackLocation _nextLocation = ScopeStackLocation.zero;

  /// Adds a scope for a given region.
  ///
  /// This method is the same as calling [push] and then [pop] with the same
  /// args.
  void add(
    String? scope, {
    required ScopeStackLocation start,
    required ScopeStackLocation end,
  }) {
    push(scope, start);
    pop(scope, end);
  }

  /// Pushes a new scope onto the stack starting at [start].
  void push(String? scope, ScopeStackLocation location) {
    if (scope == null) return;

    // If the stack is empty, seed the position which is used for the start
    // of the next produced token.
    if (stack.isEmpty) {
      _nextLocation = location;
    }

    // Whenever we push a new item, produce a span for the region between the
    // last started scope and the new current position.
    if (location.position > _nextLocation.position) {
      final scopes = stack.map((item) => item.scope).toSet();
      _produceSpan(scopes, end: location);
    }

    // Add this new scope to the stack, but don't produce its token yet. We will
    // do that when the next item is pushed (in which case we'll fill the gap),
    // or when this item is popped (in which case we'll produce a span for that
    // full region).
    stack.add(ScopeStackItem(scope, location));
  }

  /// Pops the last scope off the stack, producing a token if necessary up until
  /// [end].
  void pop(String? scope, ScopeStackLocation end) {
    if (scope == null) return null;
    assert(stack.isNotEmpty);

    final scopes = stack.map((item) => item.scope).toSet();
    final last = stack.removeLast();
    assert(last.scope == scope);
    assert(last.location.position <= end.position);

    _produceSpan(scopes, end: end);
  }

  void popAll(ScopeStackLocation location) {
    while (stack.isNotEmpty) {
      pop(stack.last.scope, location);
    }
  }

  /// Captures a marker to identify spans produced before/after this call.
  ScopeStackMarker marker() {
    return ScopeStackMarker(spanIndex: spans.length, location: _nextLocation);
  }

  /// Splits all spans created since [begin] by [condition].
  ///
  /// This is used to handle multiline spans that use begin/end such as
  /// capturing triple-backtick code blocks that would have captured the leading
  /// '/// ', which should not be included.
  void splitFromMarker(
    LineScanner scanner,
    ScopeStackMarker begin,
    RegExp condition,
  ) {
    // Remove the spans to be split. We will push new spans after splitting.
    final spansToSplit = spans.sublist(begin.spanIndex);
    if (spansToSplit.isEmpty) return;
    spans.removeRange(begin.spanIndex, spans.length);

    // Also rewind the last positions to the start place.
    _nextLocation = begin.location;

    // Add the split spans individually.
    for (final span in spansToSplit
        .expand((spanToSplit) => spanToSplit.split(scanner, condition))) {
      // To handler spans with multiple scopes, we need to push each scope, and
      // then pop each scope. We cannot use `add`.
      for (final scope in span.scopes) {
        push(scope, span.startLocation);
      }
      for (final scope in span.scopes.reversed) {
        pop(scope, span.endLocation);
      }
    }
  }

  void _produceSpan(
    Set<String> scopes, {
    required ScopeStackLocation end,
  }) {
    // Don't produce zero-width spans.
    if (end.position == _nextLocation.position) return;

    // If the new span starts at the same place that the previous one ends and
    // has the same scopes, we can replace the previous one with a single new
    // larger span.
    final newScopes = scopes.toList();
    final lastSpan = spans.lastOrNull;
    if (lastSpan != null &&
        lastSpan.endLocation.position == _nextLocation.position &&
        lastSpan.scopes.equals(newScopes)) {
      final span = ScopeSpan(
        scopes: newScopes,
        startLocation: lastSpan.startLocation,
        endLocation: end,
      );
      // Replace the last span with this one.
      spans[spans.length - 1] = span;
    } else {
      final span = ScopeSpan(
        scopes: newScopes,
        startLocation: _nextLocation,
        endLocation: end,
      );
      spans.add(span);
    }
    _nextLocation = end;
  }
}

/// An item pushed onto the scope stack, consisting of a [String] scope and a
/// location.
class ScopeStackItem {
  ScopeStackItem(this.scope, this.location);

  final String scope;
  final ScopeStackLocation location;
}

/// A marker tracking a position in the list of produced tokens.
///
/// Used for back-tracking when handling nested multiline tokens.
class ScopeStackMarker {
  ScopeStackMarker({
    required this.spanIndex,
    required this.location,
  });

  final int spanIndex;
  final ScopeStackLocation location;
}

/// A location (including offset, line, column) in the code parsed for scopes.
class ScopeStackLocation {
  const ScopeStackLocation({
    required this.position,
    required this.line,
    required this.column,
  });

  static const zero = ScopeStackLocation(position: 0, line: 0, column: 0);

  /// 0-based offset in content.
  final int position;

  /// 0-based line number of [position].
  final int line;

  /// 0-based column number of [position].
  final int column;

  /// Returns a location offset by [offset] characters.
  ///
  /// This method does not handle line wrapping so should only be used where it
  /// is known that the offset does not wrap across a line boundary.
  ScopeStackLocation offset(int offset) {
    return ScopeStackLocation(
      position: position + offset,
      line: line,
      column: column + offset,
    );
  }
}

extension LineScannerExtension on LineScanner {
  ScopeStackLocation get location =>
      ScopeStackLocation(position: position, line: line, column: column);
}

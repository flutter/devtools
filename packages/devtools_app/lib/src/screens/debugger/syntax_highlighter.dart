// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/ui/colors.dart';
import 'span_parser.dart';

final _log = Logger('syntax_highlighter');

class SyntaxHighlighter {
  SyntaxHighlighter({source}) : source = source ?? '';

  SyntaxHighlighter.withGrammar({
    Grammar? grammar,
    source,
  }) : source = source ?? '' {
    _grammar = grammar;
  }

  final String source;
  late String _processedSource;

  final _spanStack = ListQueue<ScopeSpan>();

  int _currentPosition = 0;

  late Map<String, TextStyle> _scopeStyles;

  static Grammar? _grammar;

  static Future<void> initialize() async {
    if (_grammar == null) {
      // Ensure the framework is initialized before trying to load the syntax
      // from the bundled assets.
      WidgetsFlutterBinding.ensureInitialized();
      final grammarJson = json.decode(
        await rootBundle.loadString('assets/dart_syntax.json'),
      );
      try {
        _grammar = Grammar.fromJson(grammarJson);
      } catch (error) {
        // Safari does not support negative-lookbehind regex which are currently
        // required by the syntax highlighting. An unhandled exception here will
        // prevent DevTools initializing, so just print the error and leave
        // syntax highlighting disabled if this happens.
        _log.warning(
          'Failed to load Dart Syntax Highlighting:\n'
          '$error',
        );
      }
    }
  }

  /// Returns the highlighted [source] in [TextSpan] form.
  ///
  /// If [lineRange] is provided, only the lines between
  /// `[lineRange.begin, lineRange.end]` will be returned.
  TextSpan highlight(BuildContext context, {LineRange? lineRange}) {
    // Generate the styling for the various scopes based on the current theme.
    _scopeStyles = _buildSyntaxColorTable(Theme.of(context));
    _currentPosition = 0;
    _processedSource = source;
    if (lineRange != null) {
      _processedSource = _processedSource
          .split('\n')
          .sublist(lineRange.begin - 1, lineRange.end)
          .join('\n');
    }
    final grammar = _grammar;
    if (grammar == null) {
      return TextSpan(text: _processedSource);
    }
    return TextSpan(
      children: _highlightLoopHelper(
        currentScope: null,
        loopCondition: () => _currentPosition < _processedSource.length,
        scopes: SpanParser.parse(grammar, _processedSource),
      ),
    );
  }

  /// Returns the [TextStyle] for the current span based on the current scopes.
  ///
  /// If there are multiple scopes for a span, styling for each scope is
  /// applied in the order the scopes are listed (i.e., later scope styles take
  /// precedence).
  TextStyle _getStyleForSpan() {
    if (_spanStack.isEmpty) {
      return const TextStyle();
    }
    final scopes = _spanStack.last.scopes;

    if (scopes.isEmpty) {
      return const TextStyle();
    } else if (scopes.length == 1) {
      return _scopeStyles[scopes.first] ?? const TextStyle();
    } else {
      var style = const TextStyle();
      for (final scope in scopes) {
        style = style.merge(_scopeStyles[scope] ?? const TextStyle());
      }
      return style;
    }
  }

  /// Enters a new scope for a span of text. Returns a [List<TextSpan>]
  /// containing the stylized text from within the scope.
  List<TextSpan> _scope(
    ScopeSpan currentScope,
    List<ScopeSpan> scopes,
  ) {
    return _highlightLoopHelper(
      currentScope: currentScope,
      loopCondition: () => currentScope.contains(_currentPosition),
      scopes: scopes,
    );
  }

  List<TextSpan> _highlightLoopHelper({
    required ScopeSpan? currentScope,
    required bool Function() loopCondition,
    required List<ScopeSpan> scopes,
  }) {
    final sourceSpans = <TextSpan>[];
    int? currentScopeBegin = _currentPosition;
    if (currentScope != null) {
      _spanStack.addLast(currentScope);
    }
    while (loopCondition()) {
      if (scopes.isNotEmpty && scopes.first.contains(_currentPosition)) {
        // Encountered the next scoped span. Close the current span and enter
        // the next.
        final text = _processedSource.substring(
          currentScopeBegin!,
          _currentPosition,
        );
        if (text.isNotEmpty) {
          sourceSpans.add(
            TextSpan(
              style: _getStyleForSpan(),
              text: text,
            ),
          );
        }
        sourceSpans.addAll(
          _scope(
            scopes.removeAt(0),
            scopes,
          ),
        );
        // Reset the beginning of the current span to the first position after
        // the close of the span that was just processed.
        currentScopeBegin = _currentPosition;
      } else if (_atNewline()) {
        currentScopeBegin = _processNewlines(
          sourceSpans,
          currentScopeBegin!,
        );
      } else {
        ++_currentPosition;
      }
    }
    // Reached the end of the text covered by the current span. Close the span
    // and exit the scope.
    final text = _processedSource.substring(
      currentScopeBegin!,
      _currentPosition,
    );
    if (text.isNotEmpty) {
      sourceSpans.add(
        TextSpan(
          style: _getStyleForSpan(),
          text: text,
        ),
      );
    }
    if (currentScope != null) {
      _spanStack.removeLast();
    }
    return sourceSpans;
  }

  bool _atNewline() =>
      String.fromCharCode(_processedSource.codeUnitAt(_currentPosition)) ==
      '\n';

  int? _processNewlines(List<TextSpan> sourceSpans, int currentScopeBegin) {
    final text = _processedSource.substring(
      currentScopeBegin,
      _currentPosition,
    );
    if (text.isNotEmpty) {
      sourceSpans.add(
        TextSpan(
          style: _getStyleForSpan(),
          text: _processedSource.substring(
            currentScopeBegin,
            _currentPosition,
          ),
        ),
      );
    }
    // We artificially break up spans if they contain a newline so it's easier
    // to find line boundaries when we try and populate the code view.
    do {
      sourceSpans.add(const TextSpan(text: '\n'));
      ++_currentPosition;
    } while ((_currentPosition < _processedSource.length) &&
        (String.fromCharCode(_processedSource.codeUnitAt(_currentPosition)) ==
            '\n'));
    return _currentPosition;
  }

  Map<String, TextStyle> _buildSyntaxColorTable(ThemeData theme) {
    final commentStyle = TextStyle(
      color: theme.colorScheme.commentSyntaxColor,
    );
    final functionStyle = TextStyle(
      color: theme.colorScheme.functionSyntaxColor,
    );
    final declarationStyle = TextStyle(
      color: theme.colorScheme.declarationsSyntaxColor,
    );
    final modifierStyle = TextStyle(
      color: theme.colorScheme.modifierSyntaxColor,
    );
    final controlFlowStyle = TextStyle(
      color: theme.colorScheme.controlFlowSyntaxColor,
    );
    final variableStyle = TextStyle(
      color: theme.colorScheme.variableSyntaxColor,
    );
    final stringStyle = TextStyle(
      color: theme.colorScheme.stringSyntaxColor,
    );
    final numericConstantStyle = TextStyle(
      color: theme.colorScheme.numericConstantSyntaxColor,
    );

    // Note: these scopes are defined in assets/dart_syntax.json
    const modifierScopes = <String>[
      'constant.language.dart',
      'keyword.cast.dart',
      'keyword.declaration.dart',
      'keyword.other.import.dart',
      'storage.modifier.dart',
      'storage.type.annotation.dart',
      'storage.type.primitive.dart',
    ];

    const commentScopes = <String>[
      'comment.block.dart',
      'comment.block.documentation.dart',
      'comment.block.empty.dart',
      'comment.line.double-slash.dart',
    ];

    const declarationScopes = <String>[
      'support.class.dart',
      'variable.language.dart',
    ];

    const numericConstantScopes = <String>[
      'constant.numeric.dart',
    ];

    const functionScopes = <String>[
      'entity.name.function.dart',
    ];

    const controlFlowScopes = <String>[
      'keyword.control.catch-exception.dart',
      'keyword.control.dart',
      // While 'new' is not a control flow keyword, it uses the control flow
      // color scheme so we include it here.
      'keyword.control.new.dart',
    ];

    const stringScopes = <String>[
      'string.interpolated.double.dart',
      'string.interpolated.single.dart',
      'string.interpolated.triple.double.dart',
      'string.interpolated.triple.single.dart',
      'string.quoted.double.dart',
      'string.quoted.single.dart',
      'string.quoted.triple.double.dart',
      'string.quoted.triple.single.dart',
    ];

    const variableScopes = <String>[
      // DartDoc code reference
      'variable.name.source.dart',
      // DartDoc in-line code
      'variable.other.source.dart',
      // Highlights code in strings (e.g., '$foo' or '${foo.bar()}')
      'variable.parameter.dart',
    ];

    Map<String, TextStyle> scopeTextStyleMapper(
      List<String> scopes,
      TextStyle style,
    ) {
      return {
        for (final scope in scopes) scope: style,
      };
    }

    return <String, TextStyle>{
      ...scopeTextStyleMapper(modifierScopes, modifierStyle),
      ...scopeTextStyleMapper(commentScopes, commentStyle),
      ...scopeTextStyleMapper(declarationScopes, declarationStyle),
      ...scopeTextStyleMapper(numericConstantScopes, numericConstantStyle),
      ...scopeTextStyleMapper(functionScopes, functionStyle),
      ...scopeTextStyleMapper(controlFlowScopes, controlFlowStyle),
      ...scopeTextStyleMapper(stringScopes, stringStyle),
      ...scopeTextStyleMapper(variableScopes, variableStyle),
    };
  }
}

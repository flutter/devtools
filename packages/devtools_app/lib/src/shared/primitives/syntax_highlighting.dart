// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';

final _log = Logger('syntax_highlighting');

//Future<String> loadPolyfillScript() {
//  return asset.loadString('assets/scripts/inspector_polyfill_script.dart');
//}

// https://macromates.com/manual/en/language_grammars

void main() {
  final String source = File('assets/syntax/dart.json').readAsStringSync();

  final TextmateGrammar dartGrammar = TextmateGrammar(source);
  _log.info(dartGrammar);
}

// todo: test basic parsing

class TextmateGrammar {
  TextmateGrammar(String syntaxDefinition) {
    _definition = jsonDecode(syntaxDefinition);

    _parseFileRules();
    _parseRules();
  }

  final List<Rule> _fileRules = [];
  final Map<String, Rule> _ruleMap = {};

  late final Map _definition;

  /// The name of the grammar.
  String? get name => _definition['name'];

  /// The file type extensions that the grammar should be used with.
  List<String> get fileTypes =>
      (_definition['fileTypes'] as List).cast<String>();

  void _parseRules() {
    final Map repository = _definition['repository'];
    for (final name in repository.keys.cast<String>()) {
      _ruleMap[name] = Rule(name);
    }

    for (final name in _ruleMap.keys) {
      _ruleMap[name]!._parse(repository[name]);
    }

    _log.info('rules: ${_ruleMap.keys.toList()}');
  }

  void _parseFileRules() {
    final List<Object?> patterns = _definition['patterns'];
    for (final Map info in patterns.cast<Map<Object?, Object?>>()) {
      _fileRules.add(Rule(info['name']).._parse(info));
    }
    _log.info('fileRules: $_fileRules');
  }

  @override
  String toString() => '$name: $fileTypes';
}

// todo: make abstract

// todo: have a forwarding rule

// todo: have a match rule, and a begin / end rule

class Rule {
  Rule(this.name);

  final String? name;

  void _parse(Map<Object?, Object?>? _) {
    // todo:
  }

  @override
  String toString() => '$name';
}

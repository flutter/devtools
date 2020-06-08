// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

//Future<String> loadPolyfillScript() {
//  return asset.loadString('assets/scripts/inspector_polyfill_script.dart');
//}

// https://macromates.com/manual/en/language_grammars

void main() {
  final String source = File('assets/syntax/dart.json').readAsStringSync();

  final TextmateGrammar dartGrammar = TextmateGrammar(source);
  print(dartGrammar);
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

  Map _definition;

  /// The name of the grammar.
  String get name => _definition['name'];

  /// The file type extensions that the grammar should be used with.
  List<String> get fileTypes =>
      (_definition['fileTypes'] as List).cast<String>();

  /// A unique name for the grammar.
  String get scopeName => _definition['scopeName'];

  void _parseRules() {
    final Map repository = _definition['repository'];
    for (String name in repository.keys) {
      _ruleMap[name] = Rule(name);
    }

    for (String name in _ruleMap.keys) {
      _ruleMap[name]._parse(repository[name]);
    }

    print('rules: ${_ruleMap.keys.toList()}');
  }

  void _parseFileRules() {
    final List<dynamic> patterns = _definition['patterns'];
    for (Map info in patterns) {
      _fileRules.add(Rule(info['name']).._parse(info));
    }
    print('fileRules: $_fileRules');
  }

  @override
  String toString() => '$name: $fileTypes';
}

// todo: make abstract

// todo: have a forwarding rule

// todo: have a match rule, and a begin / end rule

class Rule {
  Rule(this.name);

  final String name;

  void _parse(Map info) {
    // todo:
  }

  @override
  String toString() => '$name';
}

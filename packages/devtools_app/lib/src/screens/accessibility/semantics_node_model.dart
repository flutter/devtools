// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport 'package:flutter/semantics.dart';
library;

import 'dart:ui' show SemanticsFlag;

import '../../shared/primitives/trees.dart';

/// Represents a node in the accessibility semantics tree.
class SemanticsNodeModel extends TreeNode<SemanticsNodeModel> {
  SemanticsNodeModel({
    required this.id,
    this.label = '',
    this.flags = const <SemanticsFlag>{},
    this.widgetName = '',
  });

  /// The semantics node identifier, as provided by the Flutter framework.
  final String id;

  /// The user-visible label announced by screen readers (maps to [SemanticsData.label]).
  final String label;

  /// Semantic flags active on this node.
  final Set<SemanticsFlag> flags;

  /// The name of the Flutter widget that produced this node, if available.
  final String widgetName;

  /// Mapping from flag name strings to [SemanticsFlag] instances.
  static final _flagByName = <String, SemanticsFlag>{
    for (final flag in SemanticsFlag.values) flag.name: flag,
  };

  /// Parses a list of flag name strings into a set of [SemanticsFlag]s.
  static Set<SemanticsFlag> parseFlags(List<dynamic>? rawFlags) {
    if (rawFlags == null) return const <SemanticsFlag>{};
    return rawFlags
        .map((e) => _flagByName[e.toString()])
        .whereType<SemanticsFlag>()
        .toSet();
  }

  @override
  SemanticsNodeModel shallowCopy() {
    return SemanticsNodeModel(
      id: id,
      label: label,
      flags: flags,
      widgetName: widgetName,
    );
  }
}

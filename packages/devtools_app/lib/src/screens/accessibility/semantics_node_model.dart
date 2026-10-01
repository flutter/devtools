// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport 'package:flutter/semantics.dart';
library;

import 'dart:ui' show Rect, SemanticsFlag;

import '../../shared/primitives/trees.dart';

/// Represents a node in the accessibility semantics tree.
class SemanticsNodeModel extends TreeNode<SemanticsNodeModel> {
  SemanticsNodeModel({
    required this.id,
    this.label = '',
    this.value = '',
    this.hint = '',
    this.rect,
    this.flags = const <SemanticsFlag>{},
    this.widgetName = '',
  });

  /// The semantics node identifier, as provided by the Flutter framework.
  final String id;

  /// The user-visible label announced by screen readers (maps to [SemanticsData.label]).
  final String label;

  /// The textual description of the value of the node (maps to [SemanticsData.value]).
  final String value;

  /// A brief description of the result of performing an action on the node (maps to [SemanticsData.hint]).
  final String hint;

  /// The bounding box of the node in logical pixels (maps to [SemanticsNode.rect]).
  final Rect? rect;

  /// Semantic flags active on this node.
  final Set<SemanticsFlag> flags;

  /// The name of the Flutter widget that produced this node, if available.
  final String widgetName;

  /// Mapping from flag name strings to [SemanticsFlag] instances.
  static final _flagByName = <String, SemanticsFlag>{
    for (final flag in SemanticsFlag.values) flag.name: flag,
  };

  /// Parses a list of flag name strings into a set of [SemanticsFlag]s.
  static Set<SemanticsFlag> parseFlags(List<Object?>? rawFlags) {
    if (rawFlags == null) return const <SemanticsFlag>{};
    return rawFlags
        .map((e) => _flagByName[e?.toString()])
        .whereType<SemanticsFlag>()
        .toSet();
  }

  /// Parses a JSON representation of a bounding box into a [Rect].
  static Rect? parseRect(Object? rawRect) {
    if (rawRect is! Map) return null;
    final left = (rawRect['left'] as num?)?.toDouble();
    final top = (rawRect['top'] as num?)?.toDouble();
    if (left == null || top == null) return null;

    if (rawRect.containsKey('width') && rawRect.containsKey('height')) {
      final width = (rawRect['width'] as num?)?.toDouble();
      final height = (rawRect['height'] as num?)?.toDouble();
      if (width != null && height != null) {
        return Rect.fromLTWH(left, top, width, height);
      }
    }
    if (rawRect.containsKey('right') && rawRect.containsKey('bottom')) {
      final right = (rawRect['right'] as num?)?.toDouble();
      final bottom = (rawRect['bottom'] as num?)?.toDouble();
      if (right != null && bottom != null) {
        return Rect.fromLTRB(left, top, right, bottom);
      }
    }
    return null;
  }

  /// Formatted string representation of [rect] in `Rect.fromLTWH` syntax.
  String? get rectDisplay {
    final currentRect = rect;
    if (currentRect == null) return null;
    final left = _formatNumber(currentRect.left);
    final top = _formatNumber(currentRect.top);
    final width = _formatNumber(currentRect.width);
    final height = _formatNumber(currentRect.height);
    return 'rect: Rect.fromLTWH($left, $top, $width, $height)';
  }

  static String _formatNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  SemanticsNodeModel shallowCopy() {
    return SemanticsNodeModel(
      id: id,
      label: label,
      value: value,
      hint: hint,
      rect: rect,
      flags: flags,
      widgetName: widgetName,
    );
  }
}

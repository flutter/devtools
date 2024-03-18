// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';

import '../primitives/utils.dart';
import 'adapted_heap_data.dart';
import 'class_name.dart';

/// Heap path represented by classes only, without object details.
class PathFromRoot {
  PathFromRoot(HeapPath heapPath)
      : classes =
            heapPath.objects.map((o) => o.heapClass).toList(growable: false);
  final List<HeapClassName> classes;

  String toShortString({String? delimiter, bool inverted = false}) => _asString(
        data: classes.map((e) => e.className).toList(),
        delimiter: _delimiter(
          delimiter: delimiter,
          inverted: inverted,
          isLong: false,
        ),
        inverted: inverted,
        skipObject: true,
      );

  String toLongString({
    String? delimiter,
    bool inverted = false,
    bool hideStandard = false,
  }) {
    final List<String> data;
    bool justAddedEllipsis = false;
    if (hideStandard) {
      data = [];
      for (var item in classes.asMap().entries) {
        if (item.key == 0 ||
            item.key == classes.length - 1 ||
            !item.value.isCreatedByGoogle) {
          data.add(item.value.fullName);
          justAddedEllipsis = false;
        } else if (!justAddedEllipsis) {
          data.add('...');
          justAddedEllipsis = true;
        }
      }
    } else {
      data = classes.map((e) => e.fullName).toList();
    }

    return _asString(
      data: data,
      delimiter: _delimiter(
        delimiter: delimiter,
        inverted: inverted,
        isLong: true,
      ),
      inverted: inverted,
    );
  }

  static String _delimiter({
    required String? delimiter,
    required bool inverted,
    required bool isLong,
  }) {
    if (delimiter != null) return delimiter;
    if (isLong) {
      return inverted ? '\n← ' : '\n→ ';
    }
    return inverted ? ' ← ' : ' → ';
  }

  static String _asString({
    required List<String> data,
    required String delimiter,
    required bool inverted,
    bool skipObject = false,
  }) {
    data = data.joinWith(delimiter).toList();
    if (skipObject) data.removeAt(data.length - 1);
    if (inverted) data = data.reversed.toList();
    return data.join().trim();
  }

  late final _listEquality = const ListEquality<HeapClassName>().equals;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is PathFromRoot && _listEquality(classes, other.classes);
  }

  @override
  late final int hashCode = Object.hashAll(classes);
}

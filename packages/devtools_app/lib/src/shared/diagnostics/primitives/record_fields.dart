// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:vm_service/vm_service.dart';

class RecordFields {
  RecordFields(List<BoundField>? fields) {
    positional = <BoundField>[];
    named = <BoundField>[];
    for (final field in fields ?? []) {
      if (_isPositionalField(field)) {
        positional.add(field);
      } else {
        named.add(field);
      }
    }

    _sortPositionalFields(positional);
  }

  late final List<BoundField> positional;
  late final List<BoundField> named;

  static bool _isPositionalField(BoundField field) => field.name is int;

  // Sorts positional fields in ascending order:
  static void _sortPositionalFields(List<BoundField> fields) {
    fields.sort((field1, field2) {
      assert(field1.name is int && field2.name is int);
      final name1 = field1.name as int;
      final name2 = field2.name as int;
      return name1.compareTo(name2);
    });
  }
}

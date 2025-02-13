// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:yaml/yaml.dart';

extension YamlExtension on YamlMap {
  Map<String, Object?> toDartMap() {
    final map = <String, Object?>{};
    for (final entry in nodes.entries) {
      map[entry.key.toString()] = entry.value.convertToDartType();
    }
    return map;
  }
}

extension YamlListExtension on YamlList {
  List<Object?> toDartList() {
    final list = <Object>[];
    for (final e in nodes) {
      final element = e.convertToDartType();
      if (element != null) list.add(element);
    }
    return list;
  }
}

extension YamlNodeExtension on YamlNode {
  Object? convertToDartType() {
    return switch (this) {
      YamlMap() => (this as YamlMap).toDartMap(),
      YamlList() => (this as YamlList).toDartList(),
      _ => value,
    };
  }
}

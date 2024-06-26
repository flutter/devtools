// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// HeapSpace of Dart VM collected heap data.
class HeapSpace {
  HeapSpace._fromJson(this.json)
      : avgCollectionPeriodMillis =
            json['avgCollectionPeriodMillis'] as double?,
        capacity = json['capacity'] as int?,
        collections = json['collections'] as int?,
        external = json['external'] as int?,
        name = json['name'] as String?,
        time = json['time'] as double?,
        used = json['used'] as int?;

  static HeapSpace? parse(Map<String, Object?>? json) =>
      json == null ? null : HeapSpace._fromJson(json);

  final Map<String, Object?> json;

  final double? avgCollectionPeriodMillis;

  final int? capacity;

  final int? collections;

  final int? external;

  final String? name;

  final double? time;

  final int? used;

  Map<String, dynamic> toJson() => <String, Object?>{
        'type': 'HeapSpace',
        'avgCollectionPeriodMillis': avgCollectionPeriodMillis,
        'capacity': capacity,
        'collections': collections,
        'external': external,
        'name': name,
        'time': time,
        'used': used,
      };

  @override
  String toString() => '[HeapSpace]';
}

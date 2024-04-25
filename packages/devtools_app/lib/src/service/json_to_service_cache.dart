// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

/// Converts JSON strings to fake VM service response objects, allowing for
/// the reuse of various data structures that require package:vm_service types.
class JsonToServiceCache {
  final _cache = <String, Instance>{
    _kTrue.id!: _kTrue,
    _kFalse.id!: _kFalse,
    _kNull.id!: _kNull,
  };

  int _idCount = 0;
  String _nextId() => 'json-cache-${_idCount++}';

  static final _kTrue = Instance(
    kind: InstanceKind.kBool,
    identityHashCode: -1,
    classRef: ClassRef(
      name: 'bool',
      id: 'json-cache-bool',
    ),
    valueAsString: 'true',
    id: 'json-cache-true',
  );

  static final _kFalse = Instance(
    kind: InstanceKind.kBool,
    identityHashCode: -1,
    classRef: ClassRef(
      name: 'bool',
      id: 'json-cache-bool',
    ),
    valueAsString: 'false',
    id: 'json-cache-false',
  );

  static final _kNull = Instance(
    kind: InstanceKind.kNull,
    identityHashCode: -1,
    classRef: ClassRef(
      name: 'Null',
      id: 'json-cache-null-cls',
    ),
    id: 'json-cache-null',
  );

  static final _kListClass = ClassRef(
    name: 'List',
    id: 'json-cache-list-class',
  );

  static final _kMapClass = ClassRef(
    name: 'Map',
    id: 'json-cache-map-class',
  );

  /// The current number of non-constant elements in the cache.
  @visibleForTesting
  int get length => _cache.length - 3;

  /// A 'fake' implementation of `VmService.getObject`, used to retrieve a fake
  /// service instance from the cache. If `objectId` isn't a valid reference,
  /// `null` is returned.
  ///
  /// If provided, `offset` is the start of the range within a collection that
  /// should be returned. If `offset` is provided, `count` must also be provided.
  /// The result will be an `Instance` containing `count` objects, starting from
  /// `offset`.
  Instance? getObject({
    required String objectId,
    int? offset,
    int? count,
  }) {
    final obj = _cache[objectId];
    if (obj == null) return null;
    if (offset != null && count != null) {
      // TODO(bkonyi): consider caching responses for objects with offsets and
      // counts.
      if (obj.kind == InstanceKind.kList) {
        final list = Instance(
          kind: InstanceKind.kList,
          identityHashCode: -1,
          classRef: _kListClass,
          id: _nextId(),
          offset: offset,
          count: count,
          elements: obj.elements!.getRange(offset, offset + count).toList(),
        );
        return list;
      } else if (obj.kind == InstanceKind.kMap) {
        final map = Instance(
          kind: InstanceKind.kMap,
          identityHashCode: -1,
          classRef: _kMapClass,
          id: _nextId(),
          offset: offset,
          count: count,
          associations:
              obj.associations!.getRange(offset, offset + count).toList(),
        );
        return map;
      }
    }
    return obj;
  }

  /// Recursively inserts fake [Instance] entries in the cache, returning the
  /// root [Instance] of the JSON object.
  Instance insertJsonObject(Object? json) {
    if (json is List) {
      return _insertList(json);
    } else if (json is Map) {
      return _insertMap(json.cast<String, Object?>());
    }
    return _insertPrimitive(json);
  }

  /// Recursively convert an [Instance] back to JSON that could have created it.
  Object? instanceToJson(Instance instance) {
    switch (instance.kind) {
      case InstanceKind.kMap:
        final map = <String, Object?>{};
        for (final association in instance.associations ?? <MapAssociation>[]) {
          map[(association.key as Instance).valueAsString!] =
              instanceToJson(association.value);
        }
        return map;
      case InstanceKind.kList:
        return [...instance.elements?.map((e) => instanceToJson(e)) ?? []];
      case InstanceKind.kString:
        return instance.valueAsString;
      case InstanceKind.kInt:
        final value = instance.valueAsString;
        if (value == null) {
          return null;
        } else {
          return int.parse(value);
        }
      case InstanceKind.kBool:
        final value = instance.valueAsString;
        if (value == null) {
          return null;
        } else {
          return bool.parse(value);
        }
      case InstanceKind.kDouble:
        final value = instance.valueAsString;
        if (value == null) {
          return null;
        } else {
          return double.parse(value);
        }
      case InstanceKind.kNull:
        return null;
      default:
        throw 'Unhandled instance type: ${instance.kind}';
    }
  }

  /// Recursively removes [Instance] entries in the cache starting from a root
  /// [Instance].
  void removeJsonObject(Instance root) {
    // Don't remove constants from the cache.
    if (root.kind == InstanceKind.kBool || root.kind == InstanceKind.kNull) {
      return;
    }
    assert(_cache.containsKey(root.id));
    _cache.remove(root.id);
    if (root.kind == InstanceKind.kMap) {
      for (final entry in root.associations!) {
        removeJsonObject(entry.key);
        removeJsonObject(entry.value);
      }
    } else if (root.kind == InstanceKind.kList) {
      root.elements!.cast<Instance>().forEach(removeJsonObject);
    }
  }

  Instance _insertMap(Map<String, Object?> json) {
    final map = Instance(
      kind: InstanceKind.kMap,
      identityHashCode: -1,
      classRef: _kMapClass,
      id: _nextId(),
    );

    map.associations = <MapAssociation>[
      for (final entry in json.entries)
        MapAssociation(
          key: insertJsonObject(entry.key),
          value: insertJsonObject(entry.value),
        ),
    ];
    map.length = json.length;

    _cache[map.id!] = map;
    return map;
  }

  Instance _insertList(List<Object?> json) {
    final list = Instance(
      kind: InstanceKind.kList,
      identityHashCode: -1,
      classRef: _kListClass,
      id: _nextId(),
    );
    list.elements = <Instance>[
      for (final e in json) insertJsonObject(e),
    ];
    list.length = json.length;
    _cache[list.id!] = list;
    return list;
  }

  Instance _insertPrimitive(Object? json) {
    assert(
      json == null ||
          json is String ||
          json is int ||
          json is double ||
          json is bool,
    );
    Instance instance;
    if (json == null) {
      instance = _kNull;
    } else if (json is String) {
      instance = Instance(
        kind: InstanceKind.kString,
        identityHashCode: -1,
        classRef: ClassRef(
          name: 'String',
          id: 'json-cache-string',
        ),
        id: _nextId(),
        valueAsString: json,
      );
    } else if (json is int) {
      instance = Instance(
        kind: InstanceKind.kInt,
        identityHashCode: json,
        classRef: ClassRef(
          name: 'int',
          id: 'json-cache-int',
        ),
        valueAsString: json.toString(),
        id: _nextId(),
      );
    } else if (json is double) {
      instance = Instance(
        kind: InstanceKind.kDouble,
        identityHashCode: -1,
        classRef: ClassRef(
          name: 'double',
          id: 'json-cache-double',
        ),
        valueAsString: json.toString(),
        id: _nextId(),
      );
    } else if (json is bool) {
      instance = json ? _kTrue : _kFalse;
    } else {
      throw '';
    }
    _cache[instance.id!] = instance;
    return instance;
  }
}

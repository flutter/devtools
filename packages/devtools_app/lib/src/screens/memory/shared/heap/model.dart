// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/analytics_common.dart';
import '../../../../analytics/constants.dart';
import '../../primitives/class_name.dart';
import '../../primitives/memory_utils.dart';
import '../../primitives/simple_elements.dart';

/// Names for json fields.
class _JsonFields {
  static const String objects = 'objects';
  static const String code = 'code';
  static const String references = 'references';
  static const String klass = 'klass';
  static const String library = 'library';
  static const String shallowSize = 'shallowSize';
  static const String rootIndex = 'rootIndex';
  static const String created = 'created';
}

/// Contains information from [HeapSnapshotGraph],
/// needed for memory screen.
class AdaptedHeapData {
  AdaptedHeapData(
    this.objects, {
    this.rootIndex = _defaultRootIndex,
    DateTime? created,
  })  : assert(objects.isNotEmpty),
        assert(objects.length > rootIndex) {
    this.created = created ?? DateTime.now();
  }

  factory AdaptedHeapData.fromJson(Map<String, dynamic> json) {
    final createdJson = json[_JsonFields.created];

    return AdaptedHeapData(
      (json[_JsonFields.objects] as List<dynamic>)
          .map((e) => AdaptedHeapObject.fromJson(e))
          .toList(),
      created: createdJson == null ? null : DateTime.parse(createdJson),
      rootIndex: json[_JsonFields.rootIndex] ?? _defaultRootIndex,
    );
  }

  static AdaptedHeapData fromHeapSnapshot(
    HeapSnapshotGraph graph,
  ) {
    final objects = graph.objects.map((e) {
      return AdaptedHeapObject.fromHeapSnapshotObject(e);
    }).toList();

    return AdaptedHeapData(objects);
  }

  /// Default value for rootIndex is taken from the doc:
  /// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
  static const int _defaultRootIndex = 1;

  final int rootIndex;

  AdaptedHeapObject get root => objects[rootIndex];

  final List<AdaptedHeapObject> objects;

  bool isSpanningTreeBuilt = false;

  late DateTime created;

  /// Heap objects by identityHashCode.
  late final Map<IdentityHashCode, int> _objectsByCode = Map.fromIterable(
    Iterable.generate(objects.length),
    key: (i) => objects[i].code,
    value: (i) => i,
  );

  Map<String, dynamic> toJson() => {
        _JsonFields.objects: objects.map((e) => e.toJson()).toList(),
        _JsonFields.rootIndex: rootIndex,
        _JsonFields.created: created.toIso8601String(),
      };

  int? objectIndexByIdentityHashCode(IdentityHashCode code) =>
      _objectsByCode[code];

  HeapPath? retainingPath(int objectIndex) {
    assert(isSpanningTreeBuilt);

    if (objects[objectIndex].retainer == null) return null;

    final result = <AdaptedHeapObject>[];

    while (objectIndex >= 0) {
      final object = objects[objectIndex];
      result.add(object);
      objectIndex = object.retainer!;
    }

    return HeapPath(result.reversed.toList(growable: false));
  }
}

/// Result of invocation of [identityHashCode].
typedef IdentityHashCode = int;

/// Sequence of ids of objects in the heap.
///
/// TODO(polina-c): maybe we do not need to store path by objects.
/// It can be that only classes are interesting, and we can save some
/// performance on this object. It will become clear when the leak tracking
/// feature stabilizes.
class HeapPath {
  HeapPath(this.objects);

  final List<AdaptedHeapObject> objects;

  /// Retaining path for the object in string format.
  String? shortPath() => '/${objects.map((o) => o.shortName).join('/')}/';

  /// Retaining path for the object as an array of the retaining objects.
  List<String>? detailedPath() =>
      objects.map((o) => o.name).toList(growable: false);
}

/// Heap path represented by classes only, without object details.
class ClassOnlyHeapPath {
  ClassOnlyHeapPath(HeapPath heapPath)
      : classes =
            heapPath.objects.map((o) => o.heapClass).toList(growable: false);
  final List<HeapClassName> classes;

  String toShortString({String? delimiter, bool inverted = false}) => _asString(
        data: classes.map((e) => e.className).toList(),
        delimiter: _delimeter(
          delimiter: delimiter,
          inverted: inverted,
          isLong: false,
        ),
        inverted: inverted,
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
        final isStandard =
            item.value.isDartOrFlutter || item.value.isPackageless;
        if (item.key == 0 || item.key == classes.length - 1 || !isStandard) {
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
      delimiter: _delimeter(
        delimiter: delimiter,
        inverted: inverted,
        isLong: true,
      ),
      inverted: inverted,
    );
  }

  static String _delimeter({
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
  }) =>
      (inverted ? data.reversed : data).join(delimiter);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ClassOnlyHeapPath && other.toLongString() == toLongString();
  }

  @override
  int get hashCode => toLongString().hashCode;
}

/// Contains information from [HeapSnapshotObject] needed for
/// memory analysis on memory screen.
class AdaptedHeapObject {
  AdaptedHeapObject({
    required this.code,
    required this.references,
    required this.heapClass,
    required this.shallowSize,
  });

  factory AdaptedHeapObject.fromHeapSnapshotObject(HeapSnapshotObject object) {
    return AdaptedHeapObject(
      code: object.identityHashCode,
      references: List.from(object.references),
      heapClass: HeapClassName.fromHeapSnapshotClass(object.klass),
      shallowSize: object.shallowSize,
    );
  }

  factory AdaptedHeapObject.fromJson(Map<String, dynamic> json) =>
      AdaptedHeapObject(
        code: json[_JsonFields.code],
        references: (json[_JsonFields.references] as List<dynamic>).cast<int>(),
        heapClass: HeapClassName(
          className: json[_JsonFields.klass],
          library: json[_JsonFields.library],
        ),
        shallowSize: json[_JsonFields.shallowSize] ?? 0,
      );

  final List<int> references;
  final HeapClassName heapClass;
  final IdentityHashCode code;
  final int shallowSize;

  // No serialization is needed for the fields below, because the fields are
  // calculated after the heap deserialization.

  /// Special values: `null` - the object is not reachable,
  /// `-1` - the object is root.
  int? retainer;

  /// Total shallow size of objects, where this object is retainer, recursively,
  /// plus shallow size of this object.
  ///
  /// Null, if object is not reachable.
  int? retainedSize;

  Map<String, dynamic> toJson() => {
        _JsonFields.code: code,
        _JsonFields.references: references,
        _JsonFields.klass: heapClass.className,
        _JsonFields.library: heapClass.library,
        _JsonFields.shallowSize: shallowSize,
      };

  String get shortName => '${heapClass.className}-$code';

  String get name => '${heapClass.library}/$shortName';
}

/// This class is needed to make the snapshot taking operation mockable.
class SnapshotTaker {
  Future<AdaptedHeapData?> take() async {
    final snapshot = await snapshotMemory();
    if (snapshot == null) return null;
    late final AdaptedHeapData result;
    ga.timeSync(
      memory,
      MemoryTimeAnalytics.adaptSnapshot,
      syncOperation: () => result = AdaptedHeapData.fromHeapSnapshot(snapshot),
      screenMetricsProvider: () => _SnapshotAnalyticsMetrics(
        numberOfObjects: snapshot.objects.length,
      ),
    );
    return result;
  }
}

/// Mark the object as deeply immutable.
///
/// There is no strong protection from mutation, just some asserts.
mixin Sealable {
  /// See doc for the mixin [Sealable].
  void seal() {
    _isSealed = true;
  }

  /// See doc for the mixin [Sealable].
  bool get isSealed => _isSealed;
  bool _isSealed = false;
}

class _SnapshotAnalyticsMetrics extends ScreenAnalyticsMetrics {
  _SnapshotAnalyticsMetrics({
    required this.numberOfObjects,
  });

  final int? numberOfObjects;
}

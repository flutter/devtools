// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../shared/globals.dart';

/// NOTE: this file contains extensions to classes provided by
/// `package:vm_service` in order to expose VM internal fields in a controlled
/// fashion. Objects and extensions in this class should not be used outside of
/// the `vm_developer` directory.

/// An extension on [VM] which allows for access to VM internal fields.
extension VMPrivateViewExtension on VM {
  String get embedder => json!['_embedder'];
  String get profilerMode => json!['_profilerMode'];
  int get currentMemory => json!['_currentMemory'];
  int get currentRSS => json!['_currentRSS'];
  int get maxRSS => json!['_maxRSS'];
  int? get nativeZoneMemoryUsage => json!['_nativeZoneMemoryUsage'];
}

/// An extension on [Isolate] which allows for access to VM internal fields.
extension IsolatePrivateViewExtension on Isolate {
  Map<String, dynamic> get tagCounters => json!['_tagCounters'];

  int get dartHeapSize => newSpaceUsage + oldSpaceUsage;
  int get dartHeapCapacity => newSpaceCapacity + oldSpaceCapacity;

  int get newSpaceUsage => json!['_heaps']['new']['used'];
  int get oldSpaceUsage => json!['_heaps']['old']['used'];

  int get newSpaceCapacity => json!['_heaps']['new']['capacity'];
  int get oldSpaceCapacity => json!['_heaps']['old']['capacity'];
}

extension ObjRefPrivateViewExtension on ObjRef {
  String? get vmType => json!['_vmType'];
}

extension ClassPrivateViewExtension on Class {
  String get vmName => json!['_vmName'];
}

extension FieldPrivateViewExtension on Field {
  static const guardClassKey = '_guardClass';
  static const guardClassSingle = 'single';
  static const guardClassDynamic = 'various';
  static const guardClassUnknown = 'unknown';

  bool? get guardNullable => json!['_guardNullable'];

  Future<Class?> get guardClass async {
    final guardClassType = json![guardClassKey]?['type'];
    if (guardClassType == '@Class' || guardClassType == 'Class') {
      final service = serviceManager.service!;
      final isolate = serviceManager.isolateManager.selectedIsolate.value;

      return await service.getObject(isolate!.id!, json![guardClassKey]['id'])
          as Class;
    }
    return null;
  }

  String? guardClassKind() {
    final String? guardClassType =
        json![guardClassKey] is Map ? json![guardClassKey]['type'] : null;

    if (guardClassType == '@Class' || guardClassType == 'Class') {
      return guardClassSingle;
    } else if (json![guardClassKey] == guardClassDynamic) {
      return guardClassDynamic;
    } else if (json![guardClassKey] == guardClassUnknown) {
      return guardClassUnknown;
    }
    return null;
  }
}

/// An extension on [InboundReferences] which allows for access to
/// VM internal fields.
extension InboundReferenceExtension on InboundReferences {
  static const referencesKey = 'references';
  static const parentWordOffsetKey = '_parentWordOffset';

  int? parentWordOffset(int inboundReferenceIndex) {
    return json![referencesKey]?[inboundReferenceIndex]?[parentWordOffsetKey];
  }
}

class HeapStats {
  const HeapStats({
    required this.count,
    required this.size,
    required this.externalSize,
  });

  const HeapStats.empty()
      : count = 0,
        size = 0,
        externalSize = 0;

  HeapStats.parse(List<int> stats)
      : count = stats[0],
        size = stats[1],
        externalSize = stats[2];

  final int count;
  final int size;
  final int externalSize;
}

extension ClassHeapStatsPrivateViewExtension on ClassHeapStats {
  static const newSpaceKey = '_new';
  static const oldSpaceKey = '_old';

  HeapStats get newSpace => json!.containsKey(newSpaceKey)
      ? HeapStats.parse(json![newSpaceKey].cast<int>())
      : const HeapStats.empty();
  HeapStats get oldSpace => json!.containsKey(oldSpaceKey)
      ? HeapStats.parse(json![oldSpaceKey].cast<int>())
      : const HeapStats.empty();
}

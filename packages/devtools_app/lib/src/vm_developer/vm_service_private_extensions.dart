// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

/// NOTE: this file contains extensions to classes provided by
/// `package:vm_service` in order to expose VM internal fields in a controlled
/// fashion. Objects and extensions in this class should not be used outside of
/// the `vm_developer` directory.

/// An extension on [VM] which allows for access to VM internal fields.
extension VMPrivateViewExtension on VM {
  String get embedder => json['_embedder'];
  String get profilerMode => json['_profilerMode'];
  int get currentMemory => json['_currentMemory'];
  int get currentRSS => json['_currentRSS'];
  int get maxRSS => json['_maxRSS'];
  int get nativeZoneMemoryUsage => json['_nativeZoneMemoryUsage'];
}

/// An extension on [Isolate] which allows for access to VM internal fields.
extension IsolatePrivateViewExtension on Isolate {
  List<Thread> get threads {
    return (json['_threads'].cast<Map<String, dynamic>>())
        .map((e) => Thread.parse(e))
        .toList()
        .cast<Thread>();
  }

  Map<String, dynamic> get tagCounters => json['_tagCounters'];

  int get dartHeapSize => newSpaceUsage + oldSpaceUsage;
  int get dartHeapCapacity => newSpaceCapacity + oldSpaceCapacity;

  int get newSpaceUsage => json['_heaps']['new']['used'];
  int get oldSpaceUsage => json['_heaps']['old']['used'];

  int get newSpaceCapacity => json['_heaps']['new']['capacity'];
  int get oldSpaceCapacity => json['_heaps']['old']['capacity'];

  int get zoneHandleCount => json['_numZoneHandles'];
  int get scopedHandleCount => json['_numScopedHandles'];
}

/// An internal representation of a thread running within an isolate.
class Thread {
  const Thread({
    @required this.id,
    @required this.kind,
    @required this.zoneHighWatermark,
    @required this.zoneCapacity,
  });

  factory Thread.parse(Map<String, dynamic> json) {
    return Thread(
      id: json['id'],
      kind: json['kind'],
      zoneHighWatermark: int.parse(json['_zoneHighWatermark']),
      zoneCapacity: int.parse(json['_zoneCapacity']),
    );
  }

  final String id;
  final String kind;
  final int zoneHighWatermark;
  final int zoneCapacity;
}

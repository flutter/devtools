// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

/// NOTE: this file contains extensions to classes provided by
/// `package:vm_service` in order to expose VM internal fields in a controlled
/// fashion. Objects and extensions in this class should not be used outside of
/// the `vm_developer` directory.

/// Convenience extension to create a [VMPrivateView] from a [VM].
extension VMPrivateViewExtension on VM {
  VMPrivateView toPrivateView() {
    return this == null ? null : VMPrivateView._(this);
  }
}

// TODO(bkonyi): figure out if we can properly extend VM.
/// A wrapper around [VM] which allows for access to VM internal fields.
class VMPrivateView {
  VMPrivateView._(this.vm);

  String get embedder => vm.json['_embedder'];
  String get profilerMode => vm.json['_profilerMode'];
  int get currentMemory => vm.json['_currentMemory'];
  int get currentRSS => vm.json['_currentRSS'];
  int get maxRSS => vm.json['_maxRSS'];
  int get nativeZoneMemoryUsage => vm.json['_nativeZoneMemoryUsage'];

  final VM vm;
}

/// Convenience extension to create a [IsolatePrivateView] from an [Isolate].
extension IsolatePrivateViewExtension on Isolate {
  IsolatePrivateView toPrivateView() {
    return this == null ? null : IsolatePrivateView._(this);
  }
}

// TODO(bkonyi): figure out if we can properly extend Isolate.
/// A wrapper around [Isolate] which allows for access to VM internal fields.
class IsolatePrivateView {
  IsolatePrivateView._(this.isolate);

  final Isolate isolate;

  List<Thread> get threads {
    return (isolate.json['_threads'].cast<Map<String, dynamic>>())
        .map(Thread.parse)
        .toList()
        .cast<Thread>();
  }

  Map<String, dynamic> get tagCounters => isolate.json['_tagCounters'];

  int get dartHeapSize => newSpaceUsage + oldSpaceUsage;
  int get dartHeapCapacity => newSpaceCapacity + oldSpaceCapacity;

  int get newSpaceUsage => isolate.json['_heaps']['new']['used'];
  int get oldSpaceUsage => isolate.json['_heaps']['old']['used'];

  int get newSpaceCapacity => isolate.json['_heaps']['new']['capacity'];
  int get oldSpaceCapacity => isolate.json['_heaps']['old']['capacity'];

  int get zoneHandleCount => isolate.json['_numZoneHandles'];
  int get scopedHandleCount => isolate.json['_numScopedHandles'];
}

/// An internal representation of a thread running within an isolate.
class Thread {
  const Thread({
    @required this.id,
    @required this.kind,
    @required this.zoneHighWatermark,
    @required this.zoneCapacity,
  });

  static Thread parse(Map<String, dynamic> json) {
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

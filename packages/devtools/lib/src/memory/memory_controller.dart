// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import '../vm_service_wrapper.dart';
import 'memory_protocol.dart';

/// This class contains the business logic for [memory.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class MemoryController {
  MemoryController();

  String get _isolateId => serviceManager.isolateManager.selectedIsolate.id;

  final StreamController<MemoryTracker> _memoryTrackerController =
      StreamController<MemoryTracker>.broadcast();
  Stream<MemoryTracker> get onMemory => _memoryTrackerController.stream;

  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();
  Stream<void> get onDisconnect => _disconnectController.stream;

  MemoryTracker _memoryTracker;
  MemoryTracker get memoryTracker => _memoryTracker;

  bool get hasStarted => _memoryTracker != null;

  bool hasStopped;

  void _handleIsolateChanged() {
    // TODO(terry): Need an event on the controller for this too?
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    _memoryTracker = MemoryTracker(service);
    _memoryTracker.start();

    _memoryTracker.onChange.listen((Null _) {
      _memoryTrackerController.add(_memoryTracker);
    });
  }

  void _handleConnectionStop(dynamic event) {
    _memoryTracker?.stop();
    _memoryTrackerController.add(_memoryTracker);

    _disconnectController.add(Null);
    hasStopped = true;
  }

  Future<void> startTimeline() async {
    serviceManager.isolateManager.onSelectedIsolateChanged.listen((_) {
      _handleIsolateChanged();
    });

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  Future<List<ClassHeapDetailStats>> resetAllocationProfile() =>
      getAllocationProfile(reset: true);

  // 'reset': true to reset the object allocation accumulators
  Future<List<ClassHeapDetailStats>> getAllocationProfile(
      {bool reset = false}) async {
    final Map resetArg = reset ? {'reset': 'true'} : {};

    final Response response = await serviceManager.service.callMethod(
      '_getAllocationProfile',
      isolateId: _isolateId,
      args: resetArg,
    );

    final List<dynamic> members = response.json['members'];

    final List<ClassHeapDetailStats> heapStats = members
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> d) => ClassHeapDetailStats(d))
        .where((ClassHeapDetailStats stats) {
      return stats.instancesCurrent > 0 || stats.instancesAccumulated > 0;
    }).toList();

    return heapStats;
  }

  Future<List<InstanceSummary>> getInstances(
      String classRef, String className, int maxInstances) async {
    final List<InstanceSummary> result = [];

    // TODO(terry): Expose as a stream to reduce stall when querying for 1000s
    // TODO(terry): of instances.
    final Map params = {
      'classId': classRef,
      'limit': maxInstances,
    };
    final Response response = await serviceManager.service.callMethod(
      '_getInstances',
      isolateId: _isolateId,
      args: params,
    );

    final List instances = response.json['samples'];

    for (Map instance in instances) {
      final String objectRef = instance['id'];
      result.add(InstanceSummary(classRef, className, objectRef));
    }

    return result;
  }

  Future<dynamic> getObject(String objectRef) async =>
      await serviceManager.service.getObject(
        _isolateId,
        objectRef,
      );

  Future<void> gc() async {
    await serviceManager.service.callMethod(
      '_getAllocationProfile',
      isolateId: _isolateId,
      args: {
        'gc': 'full',
      },
    );
  }

  static const int _chunkSize = 20;
  static const int _maxBytes = 200;
  static const int _maxChunks = _maxBytes ~/ _chunkSize;
  static List<BoundField> displayBytes(List<int> bytes) {
    void _displayByte(StringBuffer buff, int index) {
      final byteStr = '${bytes[index]}';
      buff.write(byteStr);
      buff.write('    '.substring(0, 4 - byteStr.length));
    }

    final List<BoundField> result = [];

    final int listSize = bytes.length;
    final int maxItems = listSize > _maxBytes ? _maxBytes : listSize;
    final int numChunks = maxItems ~/ _chunkSize;
    final int totalChunks = numChunks * _chunkSize;
    final int lastChunk = numChunks < _maxChunks ? totalChunks : -1;

    final StringBuffer buff = StringBuffer();
    for (int index = 0; index < totalChunks; index += _chunkSize) {
      buff.clear();
      for (int subIndex = 0; subIndex < _chunkSize; subIndex++)
        _displayByte(buff, index + subIndex);
      result.add(BoundField()
        ..decl = (FieldRef()..name = '[$index]')
        ..value = buff.toString());
    }

    if (lastChunk >= 0) {
      buff.clear();
      for (int index = lastChunk; index < maxItems; index++)
        _displayByte(buff, index);
      result.add(BoundField()
        ..decl = (FieldRef()..name = '[$totalChunks]')
        ..value = buff.toString());
    } else {
      result.add(BoundField()
        ..decl = (FieldRef()..name = '...$listSize ')
        ..value = 'more...');
    }

    return result;
  }
}

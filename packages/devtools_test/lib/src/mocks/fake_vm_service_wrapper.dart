// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'generated.mocks.dart';
import 'mocks.dart';

class FakeVmServiceWrapper extends Fake implements VmServiceWrapper {
  FakeVmServiceWrapper(
    this._vmFlagManager,
    this._timelineData,
    this._socketProfile,
    this._httpProfile,
    this._memoryData,
    this._allocationData,
    CpuSamples? cpuSamples,
    CpuSamples? allocationSamples,
    this._resolvedUriMap,
    this._classList,
    List<({String flagName, String value})>? flags,
  )   : _startingSockets = _socketProfile?.sockets ?? [],
        _startingRequests = _httpProfile?.requests ?? [],
        cpuSamples = cpuSamples ?? _defaultProfile,
        allocationSamples = allocationSamples ?? _defaultProfile {
    _reverseResolvedUriMap = <String, String>{};
    if (_resolvedUriMap != null) {
      for (var e in _resolvedUriMap!.entries) {
        _reverseResolvedUriMap![e.value] = e.key;
      }
    }

    for (final flag in flags ?? []) {
      unawaited(setFlag(flag.flagName, flag.value));
    }
  }

  static final _defaultProfile = CpuSamples.parse({
    'samplePeriod': 50,
    'maxStackDepth': 12,
    'sampleCount': 0,
    'timeOriginMicros': 47377796685,
    'timeExtentMicros': 3000,
    'pid': 54321,
    'functions': [],
    'samples': [],
  })!;

  CpuSamples cpuSamples;

  CpuSamples? allocationSamples;

  /// Specifies the return value of `httpEnableTimelineLogging`.
  bool httpEnableTimelineLoggingResult = true;

  /// Specifies the return value of isHttpProfilingAvailable.
  bool isHttpProfilingAvailableResult = false;

  /// Specifies the return value of `socketProfilingEnabled`.
  bool socketProfilingEnabledResult = true;

  /// Specifies the dart:io service extension version.
  SemanticVersion dartIoVersion = SemanticVersion(major: 1, minor: 3);

  final VmFlagManager _vmFlagManager;
  final Timeline? _timelineData;
  SocketProfile? _socketProfile;
  final List<SocketStatistic> _startingSockets;
  HttpProfile? _httpProfile;
  final List<HttpProfileRequest> _startingRequests;
  final SamplesMemoryJson? _memoryData;
  final AllocationMemoryJson? _allocationData;
  final Map<String, String>? _resolvedUriMap;
  final ClassList? _classList;
  late final Map<String, String>? _reverseResolvedUriMap;
  final _gcEventStream = StreamController<Event>.broadcast();

  final _flags = <String, List<Flag?>>{
    'flags': <Flag>[
      Flag(
        name: 'flag 1 name',
        comment: 'flag 1 comment contains some very long text '
            'that the renderer will have to wrap around to prevent '
            'it from overflowing the screen. This will cause a '
            'failure if one of the two Row entries the flags lay out '
            'in is not wrapped in an Expanded(), which tells the Row '
            'allocate only the remaining space to the Expanded. '
            'Without the expanded, the underlying RichTexts will try '
            'to consume as much of the layout as they can and cause '
            'an overflow.',
        valueAsString: 'flag 1 value',
        modified: false,
      ),
      Flag(
        name: profiler,
        comment: 'Mock Flag',
        valueAsString: 'true',
        modified: false,
      ),
      Flag(
        name: profilePeriod,
        comment: 'Mock Flag',
        valueAsString: CpuSamplingRate.medium.value,
        modified: false,
      ),
    ],
  };

  @override
  Future<CpuSamples> getCpuSamples(
    String isolateId,
    int timeOriginMicros,
    int timeExtentMicros,
  ) {
    return Future.value(cpuSamples);
  }

  @override
  Future<UriList> lookupPackageUris(String isolateId, List<String> uris) {
    return Future.value(
      UriList(
        uris: _resolvedUriMap != null
            ? (uris.map((e) => _resolvedUriMap![e]).toList())
            : null,
      ),
    );
  }

  @override
  Future<UriList> lookupResolvedPackageUris(
    String isolateId,
    List<String> uris, {
    bool? local,
  }) {
    return Future.value(
      UriList(
        uris: _reverseResolvedUriMap != null
            ? (uris.map((e) => _reverseResolvedUriMap![e]).toList())
            : null,
      ),
    );
  }

  @override
  Uri get connectedUri => _connectedUri;
  final _connectedUri = Uri.parse('ws://127.0.0.1:56137/ISsyt6ki0no=/ws');

  @override
  Future<void> forEachIsolate(Future<void> Function(IsolateRef) callback) =>
      callback(
        IsolateRef.parse(
          {
            'id': 'fake_isolate_id',
          },
        )!,
      );

  @override
  Future<AllocationProfile> getAllocationProfile(
    String isolateId, {
    bool? reset,
    bool? gc,
  }) async {
    final memberStats = <ClassHeapStats>[];
    for (var data in _allocationData!.data) {
      final stats = ClassHeapStats(
        classRef: data.classRef,
        accumulatedSize: 0,
        bytesCurrent: data.bytesCurrent,
        instancesAccumulated: 0,
        instancesCurrent: data.instancesCurrent,
      );
      stats.json = data.json;
      memberStats.add(stats);
    }
    final allocationProfile = AllocationProfile(
      members: memberStats,
      memoryUsage: MemoryUsage(
        externalUsage: 10000000,
        heapCapacity: 20000000,
        heapUsage: 7777777,
      ),
    );

    allocationProfile.json = allocationProfile.toJson();
    // Fake GC statistics
    allocationProfile.json![AllocationProfilePrivateViewExtension.heapsKey] =
        <String, dynamic>{
      AllocationProfilePrivateViewExtension.newSpaceKey: <String, dynamic>{
        GCStats.usedKey: 1234,
        GCStats.capacityKey: 12345,
        GCStats.collectionsKey: 42,
        GCStats.timeKey: 69,
      },
      AllocationProfilePrivateViewExtension.oldSpaceKey: <String, dynamic>{
        GCStats.usedKey: 4321,
        GCStats.capacityKey: 54321,
        GCStats.collectionsKey: 24,
        GCStats.timeKey: 96,
      },
    };

    return allocationProfile;
  }

  @override
  Future<CpuSamples> getAllocationTraces(
    String isolateId, {
    int? timeOriginMicros,
    int? timeExtentMicros,
    String? classId,
  }) async {
    return allocationSamples!;
  }

  @override
  Future<Success> setTraceClassAllocation(
    String isolateId,
    String classId,
    bool enable,
  ) async =>
      Future.value(Success());

  @override
  Future<HeapSnapshotGraph> getHeapSnapshotGraph(IsolateRef isolateRef) async {
    // Simulate a snapshot that takes .5 seconds.
    await Future.delayed(const Duration(milliseconds: 500));
    final result = MockHeapSnapshotGraph();
    when(result.name).thenReturn('name');
    when(result.classes).thenReturn([]);
    when(result.objects).thenReturn([]);
    when(result.externalProperties).thenReturn([]);
    when(result.externalSize).thenReturn(0);
    when(result.shallowSize).thenReturn(0);
    return result;
  }

  @override
  Future<Isolate> getIsolate(String isolateId) {
    return Future.value(
      Isolate.parse(
        {
          'rootLib': LibraryRef.parse(
            {
              'name': 'fake_isolate_name',
              'uri': 'package:fake_uri_root/main.dart',
            },
          ),
        },
      )!,
    );
  }

  @override
  Future<Obj> getObject(
    String isolateId,
    String objectId, {
    int? offset,
    int? count,
  }) {
    return Future.value(MockObj());
  }

  @override
  Future<MemoryUsage> getMemoryUsage(String isolateId) async {
    if (_memoryData == null) {
      throw StateError('_memoryData was not provided to FakeServiceManager');
    }

    final heapSample = _memoryData!.data.first;
    return MemoryUsage(
      externalUsage: heapSample.external,
      heapCapacity: heapSample.capacity,
      heapUsage: heapSample.used,
    );
  }

  @override
  Future<ScriptList> getScripts(String isolateId) {
    return Future.value(ScriptList(scripts: []));
  }

  @override
  Future<Stack> getStack(String isolateId, {int? limit}) {
    return Future.value(Stack(frames: [], messages: [], truncated: false));
  }

  @override
  Future<Success> setFlag(String name, String value) {
    final List<Flag?> flags = _flags['flags']!;
    final existingFlag = flags.firstWhereOrNull((f) => f?.name == name);
    if (existingFlag != null) {
      existingFlag.valueAsString = value;
    } else {
      flags.add(
        Flag.parse({
          'name': name,
          'comment': 'Mock Flag',
          'modified': true,
          'valueAsString': value,
        }),
      );
    }

    final fakeVmFlagUpdateEvent = Event(
      kind: EventKind.kVMFlagUpdate,
      flag: name,
      newValue: value,
      timestamp: 1, // 1 is arbitrary.
    );
    // This library is conceptually for testing even though it is in its own
    // package to support code reuse.
    // ignore: invalid_use_of_visible_for_testing_member
    _vmFlagManager.handleVmEvent(fakeVmFlagUpdateEvent);
    return Future.value(Success());
  }

  @override
  Future<FlagList> getFlagList() =>
      Future.value(FlagList.parse(_flags) ?? FlagList(flags: []));

  final _vmTimelineFlags = <String, Object?>{
    'type': 'TimelineFlags',
    'recordedStreams': [],
    'availableStreams': [],
  };

  @override
  Future<FakeVM> getVM() => Future.value(FakeVM());

  @override
  Future<Success> setVMTimelineFlags(List<String> recordedStreams) async {
    _vmTimelineFlags['recordedStreams'] = recordedStreams;
    return Future.value(Success());
  }

  @override
  Future<TimelineFlags> getVMTimelineFlags() =>
      Future.value(TimelineFlags.parse(_vmTimelineFlags)!);

  @override
  Future<Timeline> getVMTimeline({
    int? timeOriginMicros,
    int? timeExtentMicros,
  }) async {
    final result = _timelineData;
    if (result == null) {
      throw StateError('timelineData was not provided to FakeServiceManager');
    }
    return result;
  }

  @override
  Future<Success> clearVMTimeline() => Future.value(Success());

  @override
  Future<ClassList> getClassList(String isolateId) async {
    return _classList ?? ClassList(classes: []);
  }

  @override
  Future<bool> isSocketProfilingAvailable(String isolateId) {
    return Future.value(true);
  }

  @override
  Future<SocketProfilingState> socketProfilingEnabled(
    String isolateId, [
    bool? enabled,
  ]) {
    if (enabled != null) {
      return Future.value(SocketProfilingState(enabled: enabled));
    }
    return Future.value(
      SocketProfilingState(enabled: socketProfilingEnabledResult),
    );
  }

  @override
  Future<Success> clearSocketProfile(String isolateId) async {
    _socketProfile?.sockets.clear();
    return Future.value(Success());
  }

  @override
  Future<SocketProfile> getSocketProfile(String isolateId) {
    return Future.value(_socketProfile ?? SocketProfile(sockets: []));
  }

  void restoreFakeSockets() {
    _socketProfile = SocketProfile(sockets: _startingSockets);
  }

  @override
  Future<bool> isHttpProfilingAvailable(String isolateId) => Future.value(true);

  @override
  Future<HttpProfileRequest> getHttpProfileRequest(
    String isolateId,
    String id,
  ) async {
    final httpProfile = await getHttpProfile(isolateId);
    return Future.value(
      httpProfile.requests.firstWhere((request) => request.id == id),
    );
  }

  @override
  Future<HttpProfile> getHttpProfile(String isolateId, {int? updatedSince}) {
    return Future.value(
      _httpProfile ?? HttpProfile(requests: [], timestamp: 0),
    );
  }

  @override
  Future<Success> clearHttpProfile(String isolateId) {
    _httpProfile?.requests.clear();
    return Future.value(Success());
  }

  void restoreFakeHttpProfileRequests() {
    _httpProfile = HttpProfile(requests: _startingRequests, timestamp: 0);
  }

  @override
  Future<Success> clearCpuSamples(String isolateId) => Future.value(Success());

  @override
  Future<bool> isHttpTimelineLoggingAvailable(String isolateId) =>
      Future.value(isHttpProfilingAvailableResult);

  @override
  Future<HttpTimelineLoggingState> httpEnableTimelineLogging(
    String isolateId, [
    bool? enabled,
  ]) async {
    if (enabled != null) {
      return Future.value(HttpTimelineLoggingState(enabled: enabled));
    }
    return Future.value(
      HttpTimelineLoggingState(enabled: httpEnableTimelineLoggingResult),
    );
  }

  @override
  Future<SourceReport> getSourceReport(
    String isolateId,
    List<String> reports, {
    String? scriptId,
    int? tokenPos,
    int? endTokenPos,
    bool? forceCompile,
    bool? reportLines,
    List<String>? libraryFilters,
  }) async {
    return SourceReport(ranges: [], scripts: []);
  }

  @override
  Future<ObjectStore?> getObjectStore(String isolateId) => Future.value(
        const ObjectStore(
          fields: {},
        ),
      );

  @override
  final fakeServiceCache = JsonToServiceCache();

  @override
  Future<Timestamp> getVMTimelineMicros() async => Timestamp(timestamp: 0);

  @override
  Stream<Event> onEvent(String streamName) => const Stream.empty();

  @override
  Stream<Event> get onStdoutEvent => const Stream.empty();

  @override
  Stream<Event> get onStdoutEventWithHistory => const Stream.empty();

  @override
  Stream<Event> get onStderrEvent => const Stream.empty();

  @override
  Stream<Event> get onStderrEventWithHistory => const Stream.empty();

  @override
  Stream<Event> get onGCEvent => _gcEventStream.stream;

  void emitGCEvent() {
    _gcEventStream.sink.add(
      Event(
        kind: EventKind.kGC,
      ),
    );
  }

  @override
  Stream<Event> get onVMEvent => const Stream.empty();

  @override
  Stream<Event> get onLoggingEvent => const Stream.empty();

  @override
  Stream<Event> get onLoggingEventWithHistory => const Stream.empty();

  @override
  Stream<Event> get onExtensionEvent => const Stream.empty();

  @override
  Stream<Event> get onExtensionEventWithHistory => const Stream.empty();

  @override
  Stream<Event> get onDebugEvent => const Stream.empty();

  @override
  Stream<Event> get onTimelineEvent => const Stream.empty();

  @override
  Stream<Event> get onIsolateEvent => const Stream.empty();
}

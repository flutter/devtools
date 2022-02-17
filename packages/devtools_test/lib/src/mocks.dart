// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

class FakeInspectorService extends Fake implements InspectorService {
  @override
  ObjectGroup createObjectGroup(String debugName) {
    return ObjectGroup(debugName, this);
  }

  @override
  Future<bool> isWidgetTreeReady() async {
    return false;
  }

  @override
  Future<List<String>> inferPubRootDirectoryIfNeeded() async {
    return ['/some/directory'];
  }

  @override
  bool get useDaemonApi => true;

  @override
  final Set<InspectorServiceClient> clients = {};

  @override
  void addClient(InspectorServiceClient client) {
    clients.add(client);
  }

  @override
  void removeClient(InspectorServiceClient client) {
    clients.remove(client);
  }
}

class MockInspectorTreeController extends Mock
    implements InspectorTreeController {}

class TestInspectorController extends Fake implements InspectorController {
  InspectorService service = FakeInspectorService();

  @override
  ValueListenable<InspectorTreeNode> get selectedNode => _selectedNode;
  final ValueNotifier<InspectorTreeNode> _selectedNode = ValueNotifier(null);

  @override
  void setSelectedNode(InspectorTreeNode newSelection) {
    _selectedNode.value = newSelection;
  }

  @override
  InspectorService get inspectorService => service;
}

class FakeServiceManager extends Fake implements ServiceConnectionManager {
  FakeServiceManager({
    VmServiceWrapper service,
    this.hasConnection = true,
    this.connectedAppInitialized = true,
    this.availableServices = const [],
    this.availableLibraries = const [],
  }) : service = service ?? createFakeService() {
    initFlagManager();

    when(errorBadgeManager.erroredItemsForPage(any)).thenReturn(
        FixedValueListenable(LinkedHashMap<String, DevToolsError>()));
  }

  Completer<void> flagsInitialized = Completer();

  Future<void> initFlagManager() async {
    await _flagManager.vmServiceOpened(service);
    flagsInitialized.complete();
  }

  static FakeVmService createFakeService({
    Timeline timelineData,
    SocketProfile socketProfile,
    HttpProfile httpProfile,
    SamplesMemoryJson memoryData,
    AllocationMemoryJson allocationData,
    CpuProfileData cpuProfileData,
  }) =>
      FakeVmService(
        _flagManager,
        timelineData,
        socketProfile,
        httpProfile,
        memoryData,
        allocationData,
        cpuProfileData,
      );

  final List<String> availableServices;

  final List<String> availableLibraries;

  final MockVM _mockVM = MockVM();

  @override
  VmServiceWrapper service;

  @override
  Future<VmService> onServiceAvailable = Future.value();

  @override
  bool get isServiceAvailable => hasConnection;

  @override
  ConnectedApp connectedApp = MockConnectedApp();

  @override
  final ConsoleService consoleService = ConsoleService();

  @override
  Stream<VmServiceWrapper> get onConnectionClosed => const Stream.empty();

  @override
  Stream<VmServiceWrapper> get onConnectionAvailable => Stream.value(service);

  @override
  Future<double> get queryDisplayRefreshRate => Future.value(60.0);

  @override
  bool hasConnection;

  @override
  bool connectedAppInitialized;

  @override
  final IsolateManager isolateManager = FakeIsolateManager();

  @override
  final ErrorBadgeManager errorBadgeManager = MockErrorBadgeManager();

  @override
  final InspectorService inspectorService = FakeInspectorService();

  @override
  final TimelineStreamManager timelineStreamManager = TimelineStreamManager();

  @override
  VM get vm => _mockVM;

  // TODO(jacobr): the fact that this has to be a static final is ugly.
  static final VmFlagManager _flagManager = VmFlagManager();

  @override
  VmFlagManager get vmFlagManager => _flagManager;

  @override
  final FakeServiceExtensionManager serviceExtensionManager =
      FakeServiceExtensionManager() as ServiceExtensionManager;

  @override
  Future<Response> get rasterCacheMetrics => Future.value(Response.parse({
        'layerBytes': 0,
        'pictureBytes': 0,
      }));

  @override
  ValueListenable<bool> registeredServiceListenable(String name) {
    if (availableServices.contains(name)) {
      return ImmediateValueNotifier(true);
    }
    return ImmediateValueNotifier(false);
  }

  @override
  bool libraryUriAvailableNow(String uri) {
    return availableLibraries.any((u) => u.startsWith(uri));
  }

  @override
  Future<Response> get flutterVersion {
    return Future.value(Response.parse({
      'type': 'Success',
      'frameworkVersion': '2.10.0',
      'channel': 'unknown',
      'repositoryUrl': 'unknown source',
      'frameworkRevision': '74432fa91c8ffbc555ffc2701309e8729380a012',
      'frameworkCommitDate': '2020-05-14 13:05:34 -0700',
      'engineRevision': 'ae2222f47e788070c09020311b573542b9706a78',
      'dartSdkVersion': '2.9.0 (build 2.9.0-8.0.dev d6fed1f624)',
      'frameworkRevisionShort': '74432fa91c',
      'engineRevisionShort': 'ae2222f47e',
    }));
  }

  @override
  Future<void> sendDwdsEvent({
    @required String screen,
    @required String action,
  }) {
    return Future.value();
  }

  @override
  void manuallyDisconnect() {
    changeState(false, manual: true);
  }

  @override
  ValueListenable<ConnectedState> get connectedState => _connectedState;

  final ValueNotifier<ConnectedState> _connectedState =
      ValueNotifier(const ConnectedState(false));

  void changeState(bool value, {bool manual = false}) {
    hasConnection = value ?? false;
    _connectedState.value =
        ConnectedState(value, userInitiatedConnectionState: manual);
  }

  @override
  ValueListenable<bool> get deviceBusy => ValueNotifier(false);
}

class FakeVM extends Fake implements VM {
  FakeVM();

  @override
  Map<String, dynamic> json = {
    '_FAKE_VM': true,
    '_currentRSS': 0,
  };
}

class FakeVmService extends Fake implements VmServiceWrapper {
  FakeVmService(
    this._vmFlagManager,
    this._timelineData,
    this._socketProfile,
    this._httpProfile,
    this._memoryData,
    this._allocationData,
    CpuProfileData cpuProfileData,
  )   : _startingSockets = _socketProfile?.sockets ?? [],
        _startingRequests = _httpProfile?.requests ?? [],
        cpuProfileData = cpuProfileData ??
            CpuProfileData.parse(<String, dynamic>{
              'type': '_CpuProfileTimeline',
              'samplePeriod': 50,
              'sampleCount': 0,
              'stackDepth': 128,
              'timeOriginMicros': 47377796685,
              'timeExtentMicros': 3000,
              'traceEvents': <Map<String, dynamic>>[],
            });

  /// Specifies the return value of `httpEnableTimelineLogging`.
  bool httpEnableTimelineLoggingResult = true;

  /// Specifies the return value of isHttpProfilingAvailable.
  bool isHttpProfilingAvailableResult = false;

  /// Specifies the return value of `socketProfilingEnabled`.
  bool socketProfilingEnabledResult = true;

  /// Specifies the dart:io service extension version.
  SemanticVersion dartIoVersion = SemanticVersion(major: 1, minor: 3);

  final VmFlagManager _vmFlagManager;
  final Timeline _timelineData;
  SocketProfile _socketProfile;
  final List<SocketStatistic> _startingSockets;
  HttpProfile _httpProfile;
  final List<HttpProfileRequest> _startingRequests;
  final SamplesMemoryJson _memoryData;
  final AllocationMemoryJson _allocationData;
  final CpuProfileData cpuProfileData;

  final _flags = <String, dynamic>{
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
        valueAsString: ProfileGranularity.medium.value,
        modified: false,
      ),
    ],
  };

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
        ),
      );

  @override
  Future<AllocationProfile> getAllocationProfile(
    String isolateId, {
    bool reset,
    bool gc,
  }) async {
    final memberStats = <ClassHeapStats>[];
    for (var data in _allocationData.data) {
      final stats = ClassHeapStats(
        classRef: data.classRef,
        accumulatedSize: data.bytesDelta,
        bytesCurrent: data.bytesCurrent,
        instancesAccumulated: data.instancesDelta,
        instancesCurrent: data.instancesCurrent,
      );
      stats.json = stats.toJson();
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
    return allocationProfile;
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
    return null;
  }

  @override
  Future<Isolate> getIsolate(String isolateId) {
    return Future.value(MockIsolate());
  }

  @override
  Future<Obj> getObject(
    String isolateId,
    String objectId, {
    int offset,
    int count,
  }) {
    return Future.value(MockObj());
  }

  @override
  Future<MemoryUsage> getMemoryUsage(String isolateId) async {
    if (_memoryData == null) {
      throw StateError('_memoryData was not provided to FakeServiceManager');
    }

    final heapSample = _memoryData.data.first;
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
  Future<Stack> getStack(String isolateId, {int limit}) {
    return Future.value(Stack(frames: [], messages: [], truncated: false));
  }

  @override
  bool isProtocolVersionSupportedNow({
    @required SemanticVersion supportedVersion,
  }) {
    return true;
  }

  @override
  Future<Success> setFlag(String name, String value) {
    final List<Flag> flags = _flags['flags'];
    final existingFlag =
        flags.firstWhere((f) => f.name == name, orElse: () => null);
    if (existingFlag != null) {
      existingFlag.valueAsString = value;
    } else {
      flags.add(Flag.parse({
        'name': name,
        'comment': 'Mock Flag',
        'modified': true,
        'valueAsString': value,
      }));
    }

    final fakeVmFlagUpdateEvent = Event(
      kind: EventKind.kVMFlagUpdate,
      flag: name,
      newValue: value,
      timestamp: 1, // 1 is arbitrary.
    );
    // ignore: invalid_use_of_visible_for_testing_member
    _vmFlagManager.handleVmEvent(fakeVmFlagUpdateEvent);
    return Future.value(Success());
  }

  @override
  Future<FlagList> getFlagList() => Future.value(FlagList.parse(_flags));

  final _vmTimelineFlags = <String, dynamic>{
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
      Future.value(TimelineFlags.parse(_vmTimelineFlags));

  @override
  Future<Timeline> getVMTimeline({
    int timeOriginMicros,
    int timeExtentMicros,
  }) async {
    if (_timelineData == null) {
      throw StateError('timelineData was not provided to FakeServiceManager');
    }
    return _timelineData;
  }

  @override
  Future<Success> clearVMTimeline() => Future.value(Success());

  @override
  Future<bool> isSocketProfilingAvailable(String isolateId) {
    return Future.value(true);
  }

  @override
  Future<SocketProfilingState> socketProfilingEnabled(
    String isolateId, [
    bool enabled,
  ]) {
    if (enabled != null) {
      return Future.value(SocketProfilingState(enabled: enabled));
    }
    return Future.value(
        SocketProfilingState(enabled: socketProfilingEnabledResult));
  }

  @override
  Future<Success> clearSocketProfile(String isolateId) async {
    _socketProfile.sockets.clear();
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
    int id,
  ) async {
    final httpProfile = await getHttpProfile(isolateId);
    return Future.value(
      httpProfile.requests
          .firstWhere((request) => request.id == id, orElse: () => null),
    );
  }

  @override
  Future<HttpProfile> getHttpProfile(String isolateId, {int updatedSince}) {
    return Future.value(
      _httpProfile ?? HttpProfile(requests: [], timestamp: 0),
    );
  }

  @override
  Future<Success> clearHttpProfile(String isolateId) {
    _httpProfile?.requests?.clear();
    return Future.value(Success());
  }

  void restoreFakeHttpProfileRequests() {
    _httpProfile = HttpProfile(requests: _startingRequests, timestamp: 0);
  }

  @override
  Future<CpuProfileData> getCpuProfileTimeline(
    String isolateId,
    int origin,
    int extent,
  ) {
    return Future.value(cpuProfileData);
  }

  @override
  Future<Success> clearCpuSamples(String isolateId) => Future.value(Success());

  @override
  Future<bool> isHttpTimelineLoggingAvailable(String isolateId) =>
      Future.value(isHttpProfilingAvailableResult);

  @override
  Future<HttpTimelineLoggingState> httpEnableTimelineLogging(
    String isolateId, [
    bool enabled,
  ]) async {
    if (enabled != null) {
      return Future.value(HttpTimelineLoggingState(enabled: enabled));
    }
    return Future.value(
        HttpTimelineLoggingState(enabled: httpEnableTimelineLoggingResult));
  }

  @override
  Future<bool> isDartIoVersionSupported({
    String isolateId,
    SemanticVersion supportedVersion,
  }) {
    return Future.value(
      dartIoVersion.isSupported(supportedVersion: supportedVersion),
    );
  }

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
  Stream<Event> get onGCEvent => const Stream.empty();

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

class FakeIsolateManager extends Fake implements IsolateManager {
  @override
  ValueListenable<IsolateRef> get selectedIsolate => _selectedIsolate;
  final _selectedIsolate =
      ValueNotifier(IsolateRef.parse({'id': 'fake_isolate_id'}));

  @override
  ValueListenable<IsolateRef> get mainIsolate => _mainIsolate;
  final _mainIsolate =
      ValueNotifier(IsolateRef.parse({'id': 'fake_main_isolate_id'}));

  @override
  ValueNotifier<List<IsolateRef>> get isolates {
    return _isolates ??= ValueNotifier([_selectedIsolate.value]);
  }

  ValueNotifier<List<IsolateRef>> _isolates;

  @override
  IsolateState isolateDebuggerState(IsolateRef isolate) {
    final state = MockIsolateState();
    final mockIsolate = MockIsolate();
    when(mockIsolate.libraries).thenReturn([]);
    when(state.isolateNow).thenReturn(mockIsolate);
    return state;
  }
}

class MockIsolateState extends Mock implements IsolateState {}

class MockServiceManager extends Mock implements ServiceConnectionManager {}

class MockVmService extends Mock implements VmServiceWrapper {}

class MockIsolate extends Mock implements Isolate {}

class MockObj extends Mock implements Obj {}

// TODO(kenz): make it easier to mock a connected app by adding a constructor
// that will override the public getters on the class (e.g. isFlutterAppNow,
// isProfileBuildNow, etc.). Do this after devtools_app is migrated to null
// safety so that we can use null-safety here.
class MockConnectedApp extends Mock implements ConnectedApp {}

class FakeConnectedApp extends Mock implements ConnectedApp {}

class MockBannerMessagesController extends Mock
    implements BannerMessagesController {}

class MockLoggingController extends Mock implements LoggingController {
  @override
  ValueListenable<LogData> get selectedLog => _selectedLog;

  final _selectedLog = ValueNotifier<LogData>(null);

  @override
  void selectLog(LogData data) {
    _selectedLog.value = data;
  }
}

class MockErrorBadgeManager extends Mock implements ErrorBadgeManager {}

class MockMemoryController extends Mock implements MemoryController {}

class MockFlutterMemoryController extends Mock implements MemoryController {}

class MockPerformanceController extends Mock implements PerformanceController {}

class MockProfilerScreenController extends Mock
    implements ProfilerScreenController {}

class TestDebuggerController extends DebuggerController {
  TestDebuggerController({bool initialSwitchToIsolate = true})
      : super(initialSwitchToIsolate: initialSwitchToIsolate);

  @override
  ProgramExplorerController get programExplorerController =>
      _explorerController;
  final _explorerController = MockProgramExplorerController.withDefaults();
}

class MockDebuggerController extends Mock implements DebuggerController {
  MockDebuggerController();

  factory MockDebuggerController.withDefaults() {
    final debuggerController = MockDebuggerController();
    when(debuggerController.isPaused).thenReturn(ValueNotifier(false));
    when(debuggerController.resuming).thenReturn(ValueNotifier(false));
    when(debuggerController.breakpoints).thenReturn(ValueNotifier([]));
    when(debuggerController.isSystemIsolate).thenReturn(false);
    when(debuggerController.breakpointsWithLocation)
        .thenReturn(ValueNotifier([]));
    when(debuggerController.fileExplorerVisible)
        .thenReturn(ValueNotifier(false));
    when(debuggerController.currentScriptRef).thenReturn(ValueNotifier(null));
    when(debuggerController.sortedScripts).thenReturn(ValueNotifier([]));
    when(debuggerController.selectedBreakpoint).thenReturn(ValueNotifier(null));
    when(debuggerController.stackFramesWithLocation)
        .thenReturn(ValueNotifier([]));
    when(debuggerController.selectedStackFrame).thenReturn(ValueNotifier(null));
    when(debuggerController.hasTruncatedFrames)
        .thenReturn(ValueNotifier(false));
    when(debuggerController.scriptLocation).thenReturn(ValueNotifier(null));
    when(debuggerController.exceptionPauseMode)
        .thenReturn(ValueNotifier('Unhandled'));
    when(debuggerController.variables).thenReturn(ValueNotifier([]));
    when(debuggerController.currentParsedScript)
        .thenReturn(ValueNotifier<ParsedScript>(null));
    return debuggerController;
  }

  @override
  final programExplorerController =
      MockProgramExplorerController.withDefaults();
}

class MockProgramExplorerController extends Mock
    implements ProgramExplorerController {
  MockProgramExplorerController();

  factory MockProgramExplorerController.withDefaults() {
    final controller = MockProgramExplorerController();
    when(controller.initialized).thenReturn(ValueNotifier(true));
    when(controller.rootObjectNodes).thenReturn(ValueNotifier([]));
    when(controller.outlineNodes).thenReturn(ValueNotifier([]));
    when(controller.isLoadingOutline).thenReturn(ValueNotifier(false));

    return controller;
  }
}

class MockVM extends Mock implements VM {}

/// Fake that simplifies writing UI tests that depend on the
/// ServiceExtensionManager.
// TODO(jacobr): refactor ServiceExtensionManager so this fake can reuse more
// code from ServiceExtensionManager instead of reimplementing it.
class FakeServiceExtensionManager extends Fake
    implements ServiceExtensionManager {
  bool _firstFrameEventReceived = false;

  final _serviceExtensionStateController =
      <String, ValueNotifier<ServiceExtensionState>>{};

  final _serviceExtensionAvailable = <String, ValueNotifier<bool>>{};

  /// All available service extensions.
  final _serviceExtensions = <String>{};

  /// All service extensions that are currently enabled.
  final _enabledServiceExtensions = <String, ServiceExtensionState>{};

  /// Temporarily stores service extensions that we need to add. We should not
  /// add extensions until the first frame event has been received
  /// [_firstFrameEventReceived].
  final _pendingServiceExtensions = <String>{};

  /// Hook to simulate receiving the first frame event.
  ///
  /// Service extensions are only reported once a frame has been received.
  void fakeFrame() async {
    await _onFrameEventReceived();
  }

  Map<String, dynamic> extensionValueOnDevice = {};

  @override
  ValueListenable<bool> hasServiceExtension(String name) {
    return _hasServiceExtension(name);
  }

  ValueNotifier<bool> _hasServiceExtension(String name) {
    return _serviceExtensionAvailable.putIfAbsent(
      name,
      () => ValueNotifier(_hasServiceExtensionNow(name)),
    );
  }

  bool _hasServiceExtensionNow(String name) {
    return _serviceExtensions.contains(name);
  }

  /// Hook for tests to call to simulate adding a service extension.
  Future<void> fakeAddServiceExtension(String name) async {
    if (_firstFrameEventReceived) {
      assert(_pendingServiceExtensions.isEmpty);
      await _addServiceExtension(name);
    } else {
      _pendingServiceExtensions.add(name);
    }
  }

  /// Hook for tests to call to fake changing the state of a service
  /// extension.
  void fakeServiceExtensionStateChanged(
    final String name,
    String valueFromJson,
  ) async {
    final extension = serviceExtensionsAllowlist[name];
    if (extension != null) {
      final dynamic value = _getExtensionValueFromJson(name, valueFromJson);

      final enabled = extension is ToggleableServiceExtensionDescription
          ? value == extension.enabledValue
          // For extensions that have more than two states
          // (enabled / disabled), we will always consider them to be
          // enabled with the current value.
          : true;

      await setServiceExtensionState(
        name,
        enabled: enabled,
        value: value,
        callExtension: false,
      );
    }
  }

  dynamic _getExtensionValueFromJson(String name, String valueFromJson) {
    final expectedValueType =
        serviceExtensionsAllowlist[name].values.first.runtimeType;
    switch (expectedValueType) {
      case bool:
        return valueFromJson == 'true' ? true : false;
      case int:
      case double:
        return num.parse(valueFromJson);
      default:
        return valueFromJson;
    }
  }

  Future<void> _onFrameEventReceived() async {
    if (_firstFrameEventReceived) {
      // The first frame event was already received.
      return;
    }
    _firstFrameEventReceived = true;

    for (String extension in _pendingServiceExtensions) {
      await _addServiceExtension(extension);
    }
    _pendingServiceExtensions.clear();
  }

  Future<void> _addServiceExtension(String name) {
    _hasServiceExtension(name).value = true;

    _serviceExtensions.add(name);

    if (_enabledServiceExtensions.containsKey(name)) {
      // Restore any previously enabled states by calling their service
      // extension. This will restore extension states on the device after a hot
      // restart. [_enabledServiceExtensions] will be empty on page refresh or
      // initial start.
      return callServiceExtension(name, _enabledServiceExtensions[name].value);
    } else {
      // Set any extensions that are already enabled on the device. This will
      // enable extension states in DevTools on page refresh or initial start.
      return _restoreExtensionFromDevice(name);
    }
  }

  @override
  ValueListenable<ServiceExtensionState> getServiceExtensionState(String name) {
    return _serviceExtensionState(name);
  }

  ValueNotifier<ServiceExtensionState> _serviceExtensionState(String name) {
    return _serviceExtensionStateController.putIfAbsent(
      name,
      () {
        return ValueNotifier<ServiceExtensionState>(
          _enabledServiceExtensions.containsKey(name)
              ? _enabledServiceExtensions[name]
              : ServiceExtensionState(enabled: false, value: null),
        );
      },
    );
  }

  Future<void> _restoreExtensionFromDevice(String name) async {
    if (!serviceExtensionsAllowlist.containsKey(name)) {
      return;
    }
    final extensionDescription = serviceExtensionsAllowlist[name];
    final value = extensionValueOnDevice[name];
    if (extensionDescription is ToggleableServiceExtensionDescription) {
      if (value == extensionDescription.enabledValue) {
        await setServiceExtensionState(
          name,
          enabled: true,
          value: value,
          callExtension: false,
        );
      }
    } else {
      await setServiceExtensionState(
        name,
        enabled: true,
        value: value,
        callExtension: false,
      );
    }
  }

  Future<void> callServiceExtension(String name, dynamic value) async {
    extensionValueOnDevice[name] = value;
  }

  @override
  void vmServiceClosed() {
    _firstFrameEventReceived = false;
    _pendingServiceExtensions.clear();
    _serviceExtensions.clear();
    for (var listenable in _serviceExtensionAvailable.values) {
      listenable.value = false;
    }
  }

  /// Sets the state for a service extension and makes the call to the VMService.
  @override
  Future<void> setServiceExtensionState(
    String name, {
    @required bool enabled,
    @required dynamic value,
    bool callExtension = true,
  }) async {
    if (callExtension && _serviceExtensions.contains(name)) {
      await callServiceExtension(name, value);
    }

    _serviceExtensionState(name).value = ServiceExtensionState(
      enabled: enabled,
      value: value,
    );

    // Add or remove service extension from [enabledServiceExtensions].
    if (enabled) {
      _enabledServiceExtensions[name] = ServiceExtensionState(
        enabled: enabled,
        value: value,
      );
    } else {
      _enabledServiceExtensions.remove(name);
    }
  }

  @override
  bool isServiceExtensionAvailable(String name) {
    return _serviceExtensions.contains(name) ||
        _pendingServiceExtensions.contains(name);
  }
}

Future<void> ensureInspectorDependencies() async {
  assert(
    !kIsWeb,
    'Attempted to resolve a package path from web code.\n'
    'Package path resolution uses dart:io, which is not available in web.'
    '\n'
    "To fix this, mark the failing test as @TestOn('vm')",
  );
}

void mockIsFlutterApp(
  MockConnectedApp connectedApp, {
  bool isFlutterApp = true,
  bool isProfileBuild = false,
}) {
  when(connectedApp.isFlutterAppNow).thenReturn(isFlutterApp);
  when(connectedApp.isFlutterApp).thenAnswer((_) => Future.value(isFlutterApp));
  when(connectedApp.connectedAppInitialized).thenReturn(true);
  when(connectedApp.isDebugFlutterAppNow)
      .thenReturn(!isProfileBuild && isFlutterApp);
  when(connectedApp.isProfileBuildNow).thenReturn(isProfileBuild);
}

void mockFlutterVersion(
  MockConnectedApp connectedApp,
  SemanticVersion version,
) {
  when(connectedApp.flutterVersionNow).thenReturn(FlutterVersion.parse({
    'frameworkVersion': '$version',
  }));
  when(connectedApp.connectedAppInitialized).thenReturn(true);
}

void mockIsDartVmApp(MockConnectedApp connectedApp, [isDartVmApp = true]) {
  when(connectedApp.isRunningOnDartVM).thenReturn(isDartVmApp);
  when(connectedApp.connectedAppInitialized).thenReturn(true);
}

// ignore: prefer_single_quotes
final Grammar mockGrammar = Grammar.fromJson(jsonDecode("""
{
  "name": "Dart",
  "fileTypes": [
    "dart"
  ],
  "scopeName": "source.dart",
  "patterns": [],
  "repository": {}
}
"""));

final Script mockScript = Script.parse(jsonDecode("""
{
  "type": "Script",
  "class": {
    "type": "@Class",
    "fixedId": true,
    "id": "classes/11",
    "name": "Script",
    "library": {
      "type": "@Instance",
      "_vmType": "null",
      "class": {
        "type": "@Class",
        "fixedId": true,
        "id": "classes/148",
        "name": "Null",
        "location": {
          "type": "SourceLocation",
          "script": {
            "type": "@Script",
            "fixedId": true,
            "id": "libraries/@0150898/scripts/dart%3Acore%2Fnull.dart/0",
            "uri": "dart:core/null.dart",
            "_kind": "kernel"
          },
          "tokenPos": 925,
          "endTokenPos": 1165
        },
        "library": {
          "type": "@Library",
          "fixedId": true,
          "id": "libraries/@0150898",
          "name": "dart.core",
          "uri": "dart:core"
        }
      },
      "kind": "Null",
      "fixedId": true,
      "id": "objects/null",
      "valueAsString": "null"
    }
  },
  "size": 80,
  "fixedId": true,
  "id": "libraries/@783137924/scripts/package%3Agallery%2Fmain.dart/17b557e5bc3",
  "uri": "package:gallery/main.dart",
  "_kind": "kernel",
  "_loadTime": 1629226949571,
  "library": {
    "type": "@Library",
    "fixedId": true,
    "id": "libraries/@783137924",
    "name": "",
    "uri": "package:gallery/main.dart"
  },
  "lineOffset": 0,
  "columnOffset": 0,
  "source": "// Copyright 2019 The Flutter team. All rights reserved.\\n// Use of this source code is governed by a BSD-style license that can be\\n// found in the LICENSE file.\\n\\nimport 'package:flutter/foundation.dart';\\nimport 'package:flutter/material.dart';\\nimport 'package:flutter/scheduler.dart' show timeDilation;\\nimport 'package:flutter_gen/gen_l10n/gallery_localizations.dart';\\nimport 'package:flutter_localized_locales/flutter_localized_locales.dart';\\nimport 'package:gallery/constants.dart';\\nimport 'package:gallery/data/gallery_options.dart';\\nimport 'package:gallery/pages/backdrop.dart';\\nimport 'package:gallery/pages/splash.dart';\\nimport 'package:gallery/routes.dart';\\nimport 'package:gallery/themes/gallery_theme_data.dart';\\nimport 'package:google_fonts/google_fonts.dart';\\n\\nexport 'package:gallery/data/demos.dart' show pumpDeferredLibraries;\\n\\nvoid main() {\\n  GoogleFonts.config.allowRuntimeFetching = false;\\n  runApp(const GalleryApp());\\n}\\n\\nclass GalleryApp extends StatelessWidget {\\n  const GalleryApp({\\n    Key key,\\n    this.initialRoute,\\n    this.isTestMode = false,\\n  }) : super(key: key);\\n\\n  final bool isTestMode;\\n  final String initialRoute;\\n\\n  @override\\n  Widget build(BuildContext context) {\\n    return ModelBinding(\\n      initialModel: GalleryOptions(\\n        themeMode: ThemeMode.system,\\n        textScaleFactor: systemTextScaleFactorOption,\\n        customTextDirection: CustomTextDirection.localeBased,\\n        locale: null,\\n        timeDilation: timeDilation,\\n        platform: defaultTargetPlatform,\\n        isTestMode: isTestMode,\\n      ),\\n      child: Builder(\\n        builder: (context) {\\n          return MaterialApp(\\n            // By default on desktop, scrollbars are applied by the\\n            // ScrollBehavior. This overrides that. All vertical scrollables in\\n            // the gallery need to be audited before enabling this feature,\\n            // see https://github.com/flutter/gallery/issues/523\\n            scrollBehavior:\\n                const MaterialScrollBehavior().copyWith(scrollbars: false),\\n            restorationScopeId: 'rootGallery',\\n            title: 'Flutter Gallery',\\n            debugShowCheckedModeBanner: false,\\n            themeMode: GalleryOptions.of(context).themeMode,\\n            theme: GalleryThemeData.lightThemeData.copyWith(\\n              platform: GalleryOptions.of(context).platform,\\n            ),\\n            darkTheme: GalleryThemeData.darkThemeData.copyWith(\\n              platform: GalleryOptions.of(context).platform,\\n            ),\\n            localizationsDelegates: const [\\n              ...GalleryLocalizations.localizationsDelegates,\\n              LocaleNamesLocalizationsDelegate()\\n            ],\\n            initialRoute: initialRoute,\\n            supportedLocales: GalleryLocalizations.supportedLocales,\\n            locale: GalleryOptions.of(context).locale,\\n            localeResolutionCallback: (locale, supportedLocales) {\\n              deviceLocale = locale;\\n              return locale;\\n            },\\n            onGenerateRoute: RouteConfiguration.onGenerateRoute,\\n          );\\n        },\\n      ),\\n    );\\n  }\\n}\\n\\nclass RootPage extends StatelessWidget {\\n  const RootPage({\\n    Key key,\\n  }) : super(key: key);\\n\\n  @override\\n  Widget build(BuildContext context) {\\n    return const ApplyTextOptions(\\n      child: SplashPage(\\n        child: Backdrop(),\\n      ),\\n    );\\n  }\\n}\\n",
  "tokenPosTable": [
    [
      20,
      842,
      1,
      847,
      6,
      851,
      10,
      854,
      13
    ],
    [
      21,
      870,
      15,
      877,
      22
    ],
    [
      22,
      909,
      3,
      922,
      16
    ],
    [
      23,
      937,
      1
    ],
    [
      25,
      940,
      1
    ],
    [
      26,
      985,
      3,
      991,
      9,
      1001,
      19
    ],
    [
      27,
      1012,
      9
    ],
    [
      28,
      1026,
      10
    ],
    [
      29,
      1049,
      10,
      1062,
      23
    ],
    [
      30,
      1076,
      8,
      1087,
      19,
      1091,
      23
    ],
    [
      32,
      1107,
      14,
      1117,
      24
    ],
    [
      33,
      1134,
      16,
      1146,
      28
    ],
    [
      35,
      1151,
      3,
      1152,
      4
    ],
    [
      36,
      1170,
      10,
      1175,
      15,
      1189,
      29,
      1198,
      38
    ],
    [
      37,
      1204,
      5,
      1211,
      12
    ],
    [
      38,
      1245,
      21
    ],
    [
      39,
      1290,
      30
    ],
    [
      40,
      1323,
      26
    ],
    [
      41,
      1401,
      50
    ],
    [
      43,
      1458,
      23
    ],
    [
      44,
      1490,
      19
    ],
    [
      45,
      1533,
      21
    ],
    [
      47,
      1567,
      14
    ],
    [
      48,
      1593,
      18,
      1594,
      19,
      1603,
      28
    ],
    [
      49,
      1615,
      11,
      1622,
      18
    ],
    [
      55,
      1974,
      23,
      1999,
      48
    ],
    [
      59,
      2198,
      39,
      2201,
      42,
      2210,
      51
    ],
    [
      60,
      2257,
      37,
      2272,
      52
    ],
    [
      61,
      2321,
      40,
      2324,
      43,
      2333,
      52
    ],
    [
      63,
      2398,
      41,
      2412,
      55
    ],
    [
      64,
      2461,
      40,
      2464,
      43,
      2473,
      52
    ],
    [
      66,
      2534,
      37
    ],
    [
      70,
      2694,
      27
    ],
    [
      71,
      2759,
      52
    ],
    [
      72,
      2812,
      36,
      2815,
      39,
      2824,
      48
    ],
    [
      73,
      2870,
      39,
      2871,
      40,
      2879,
      48,
      2897,
      66
    ],
    [
      74,
      2913,
      15,
      2928,
      30
    ],
    [
      75,
      2950,
      15,
      2957,
      22
    ],
    [
      76,
      2977,
      13,
      2978,
      14
    ],
    [
      77,
      3028,
      49
    ],
    [
      79,
      3066,
      9,
      3067,
      10
    ],
    [
      82,
      3087,
      3
    ],
    [
      83,
      3089,
      1
    ],
    [
      85,
      3092,
      1
    ],
    [
      86,
      3135,
      3,
      3141,
      9,
      3149,
      17
    ],
    [
      87,
      3160,
      9
    ],
    [
      88,
      3172,
      8,
      3183,
      19,
      3187,
      23
    ],
    [
      90,
      3192,
      3,
      3193,
      4
    ],
    [
      91,
      3211,
      10,
      3216,
      15,
      3230,
      29,
      3239,
      38
    ],
    [
      92,
      3245,
      5,
      3258,
      18
    ],
    [
      97,
      3346,
      3
    ],
    [
      98,
      3348,
      1
    ]
  ]
}
"""));

final mockScriptRef = ScriptRef(
    uri:
        'libraries/@783137924/scripts/package%3Agallery%2Fmain.dart/17b557e5bc3"',
    id: 'test-script-long-lines');

final mockParsedScript = ParsedScript(
    script: mockScript,
    highlighter: SyntaxHighlighter.withGrammar(
        grammar: mockGrammar, source: mockScript.source),
    executableLines: <int>{});

final mockScriptRefs = [
  ScriptRef(uri: 'zoo:animals/cats/meow.dart', id: 'fake/id/1'),
  ScriptRef(uri: 'zoo:animals/cats/purr.dart', id: 'fake/id/2'),
  ScriptRef(uri: 'zoo:animals/dogs/bark.dart', id: 'fake/id/3'),
  ScriptRef(uri: 'zoo:animals/dogs/growl.dart', id: 'fake/id/4'),
  ScriptRef(uri: 'zoo:animals/insects/caterpillar.dart', id: 'fake/id/5'),
  ScriptRef(uri: 'zoo:animals/insects/cicada.dart', id: 'fake/id/6'),
  ScriptRef(uri: 'kitchen:food/catering/party.dart', id: 'fake/id/7'),
  ScriptRef(uri: 'kitchen:food/carton/milk.dart', id: 'fake/id/8'),
  ScriptRef(uri: 'kitchen:food/milk/carton.dart', id: 'fake/id/9'),
  ScriptRef(uri: 'travel:adventure/cave_tours_europe.dart', id: 'fake/id/10'),
  ScriptRef(uri: 'travel:canada/banff.dart', id: 'fake/id/11'),
];

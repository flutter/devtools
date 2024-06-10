// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../helpers/utils.dart';
import 'fake_isolate_manager.dart';
import 'fake_service_extension_manager.dart';
import 'fake_vm_service_wrapper.dart';
import 'generated.mocks.dart';
import 'mocks.dart';

class FakeServiceConnectionManager extends Fake
    implements ServiceConnectionManager {
  FakeServiceConnectionManager({
    VmServiceWrapper? service,
    bool hasConnection = true,
    bool connectedAppInitialized = true,
    bool hasService = true,
    List<String> availableServices = const [],
    List<String> availableLibraries = const [],
    String? rootLibrary,
  }) {
    _serviceManager = FakeServiceManager(
      service: service,
      hasConnection: hasConnection,
      connectedAppInitialized: connectedAppInitialized,
      availableLibraries: availableLibraries,
      availableServices: availableServices,
      rootLibrary: rootLibrary,
    );
    for (final screenId in screenIds) {
      when(errorBadgeManager.erroredItemsForPage(screenId)).thenReturn(
        FixedValueListenable(LinkedHashMap<String, DevToolsError>()),
      );
      when(errorBadgeManager.errorCountNotifier(screenId))
          .thenReturn(ValueNotifier<int>(0));
    }
  }

  @override
  FakeServiceManager get serviceManager =>
      _serviceManager as FakeServiceManager;
  late final ServiceManager<VmServiceWrapper> _serviceManager;

  @override
  late final appState = AppState(serviceManager.isolateManager.selectedIsolate);

  @override
  final consoleService = ConsoleService();

  @override
  final errorBadgeManager = MockErrorBadgeManager();

  @override
  final inspectorService = FakeInspectorService();

  @override
  final timelineStreamManager = TimelineStreamManager();

  @override
  VmFlagManager get vmFlagManager => FakeServiceManager._flagManager;

  @override
  Future<double> get queryDisplayRefreshRate => Future.value(60.0);

  @override
  Future<Response> get rasterCacheMetrics => Future.value(
        Response.parse({
          'layerBytes': 0,
          'pictureBytes': 0,
        })!,
      );

  @override
  Future<void> sendDwdsEvent({
    required String screen,
    required String action,
  }) {
    return Future.value();
  }

  @override
  Future<String?> mainIsolateRootLibraryUriAsString() {
    final fakeIsolateManager =
        _serviceManager.isolateManager as FakeIsolateManager;
    return Future.value(fakeIsolateManager.rootLibrary);
  }
}

// ignore: subtype_of_sealed_class, fake for testing.
class FakeServiceManager extends Fake
    implements ServiceManager<VmServiceWrapper> {
  FakeServiceManager({
    VmServiceWrapper? service,
    this.hasConnection = true,
    this.connectedAppInitialized = true,
    this.availableServices = const [],
    this.availableLibraries = const [],
    this.onVmServiceOpened,
    Map<String, Response>? serviceExtensionResponses,
    String? rootLibrary,
  })  : serviceExtensionResponses =
            serviceExtensionResponses ?? _defaultServiceExtensionResponses,
        _isolateManager = FakeIsolateManager(rootLibrary: rootLibrary) {
    this.service = service ?? createFakeService();
    serviceUri = this.service!.wsUri;
    mockConnectedApp(
      connectedApp!,
      isFlutterApp: true,
      isProfileBuild: false,
      isWebApp: false,
    );

    when(vm.operatingSystem).thenReturn('macos');
    unawaited(vmServiceOpened(this.service!, onClosed: Future.value()));
  }

  static FakeVmServiceWrapper createFakeService({
    PerfettoTimeline? timelineData,
    SocketProfile? socketProfile,
    HttpProfile? httpProfile,
    SamplesMemoryJson? memoryData,
    AllocationMemoryJson? allocationData,
    CpuSamples? cpuSamples,
    CpuSamples? allocationSamples,
    Map<String, String>? resolvedUriMap,
    ClassList? classList,
    List<({String flagName, String value})>? vmFlags,
  }) =>
      FakeVmServiceWrapper(
        _flagManager,
        timelineData,
        socketProfile,
        httpProfile,
        memoryData,
        allocationData,
        cpuSamples,
        allocationSamples,
        resolvedUriMap,
        classList,
        vmFlags,
      );

  final List<String> availableServices;

  final List<String> availableLibraries;

  final void Function()? onVmServiceOpened;

  final Map<String, Response> serviceExtensionResponses;

  final IsolateManager _isolateManager;

  static final _defaultServiceExtensionResponses = <String, Response>{
    isImpellerEnabled: Response.parse({'enabled': false})!,
  };

  @override
  VmServiceWrapper? service;

  @override
  String? serviceUri;

  @override
  VM get vm => _mockVM;
  final _mockVM = MockVM();

  @override
  Future<VmService> onServiceAvailable = Future.value(MockVmService());

  @override
  bool get isServiceAvailable => hasConnection;

  @override
  bool hasConnection;

  @override
  bool connectedAppInitialized;

  @override
  IsolateManager get isolateManager => _isolateManager;

  @override
  final resolvedUriManager = ResolvedUriManager();

  @override
  // ignore: avoid-explicit-type-declaration, required to override base class.
  final FakeServiceExtensionManager serviceExtensionManager =
      FakeServiceExtensionManager();

  @override
  ConnectedApp? connectedApp = MockConnectedApp();

  @override
  RootInfo rootInfoNow() => RootInfo('package:myPackage/myPackage.dart');

  @override
  Future<RootInfo?> tryToDetectMainRootInfo() => Future.value(rootInfoNow());

  @override
  bool get isMainIsolatePaused {
    final state = isolateManager.mainIsolateState! as MockIsolateState;
    return state.isPaused.value;
  }

  set isMainIsolatePaused(bool value) {
    final state = isolateManager.mainIsolateState! as MockIsolateState;
    when(state.isPaused).thenReturn(ValueNotifier(value));
  }

  @override
  Future<Response> callServiceExtensionOnMainIsolate(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    if (!serviceExtensionResponses.containsKey(method)) {
      throw UnimplementedError(
        'Unimplemented response for service extension: $method',
      );
    }
    return serviceExtensionResponses[method]!;
  }

  @override
  ValueListenable<bool> registeredServiceListenable(String name) {
    if (availableServices.contains(name)) {
      return ImmediateValueNotifier(true);
    }
    return ImmediateValueNotifier(false);
  }

  @override
  bool libraryUriAvailableNow(String? uri) {
    if (uri == null) return false;
    return availableLibraries.any((u) => u.startsWith(uri));
  }

  @override
  Future<void> manuallyDisconnect() async {
    changeState(false, manual: true);
  }

  @override
  ValueListenable<ConnectedState> get connectedState => _connectedState;

  final _connectedState =
      ValueNotifier<ConnectedState>(const ConnectedState(false));

  void changeState(bool value, {bool manual = false}) {
    hasConnection = value;
    _connectedState.value =
        ConnectedState(value, userInitiatedConnectionState: manual);
  }

  @override
  ValueListenable<bool> get deviceBusy => ValueNotifier(false);

  @override
  Future<Response> get flutterVersion {
    return Future.value(
      Response.parse({
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
      })!,
    );
  }

  // TODO(jacobr): the fact that this has to be a static final is ugly.
  static final _flagManager = VmFlagManager();

  Completer<void> flagsInitialized = Completer();

  Future<void> initFlagManager() async {
    await _flagManager.vmServiceOpened(service!);
    flagsInitialized.complete();
  }

  @override
  Future<void> vmServiceOpened(
    VmServiceWrapper service, {
    required Future<void> onClosed,
  }) async {
    onVmServiceOpened?.call();
    resolvedUriManager.vmServiceOpened(service);
    await initFlagManager();
    return Future.value();
  }
}

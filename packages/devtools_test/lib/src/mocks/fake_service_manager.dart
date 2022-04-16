// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'fake_service_extension_manager.dart';
import 'fake_vm_service_wrapper.dart';
import 'generated.mocks.dart';
import 'mocks.dart';

class FakeServiceManager extends Fake implements ServiceConnectionManager {
  FakeServiceManager({
    VmServiceWrapper? service,
    this.hasConnection = true,
    this.connectedAppInitialized = true,
    this.hasService = true,
    this.availableServices = const [],
    this.availableLibraries = const [],
  }) : service = service ?? createFakeService() {
    initFlagManager();
  }

  Completer<void> flagsInitialized = Completer();

  Future<void> initFlagManager() async {
    await _flagManager.vmServiceOpened(service!);
    flagsInitialized.complete();
  }

  static FakeVmServiceWrapper createFakeService({
    Timeline? timelineData,
    SocketProfile? socketProfile,
    HttpProfile? httpProfile,
    SamplesMemoryJson? memoryData,
    AllocationMemoryJson? allocationData,
    CpuProfileData? cpuProfileData,
    CpuSamples? cpuSamples,
  }) =>
      FakeVmServiceWrapper(
        _flagManager,
        timelineData,
        socketProfile,
        httpProfile,
        memoryData,
        allocationData,
        cpuSamples,
      );

  final List<String> availableServices;

  final List<String> availableLibraries;

  final MockVM _mockVM = MockVM();

  @override
  VmServiceWrapper? service;

  @override
  Future<VmService> onServiceAvailable = Future.value(MockVmService());

  @override
  bool get isServiceAvailable => hasConnection;

  @override
  ConnectedApp? connectedApp = MockConnectedApp();

  @override
  final ConsoleService consoleService = ConsoleService();

  @override
  Stream<VmServiceWrapper> get onConnectionClosed => const Stream.empty();

  @override
  Stream<VmServiceWrapper> get onConnectionAvailable => Stream.value(service!);

  @override
  Future<double> get queryDisplayRefreshRate => Future.value(60.0);

  @override
  bool hasConnection;

  @override
  bool hasService;

  @override
  bool connectedAppInitialized;

  @override
  final IsolateManager isolateManager = FakeIsolateManager();

  @override
  final errorBadgeManager = MockErrorBadgeManager();

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
      FakeServiceExtensionManager();

  @override
  Future<Response> get rasterCacheMetrics => Future.value(
        Response.parse({
          'layerBytes': 0,
          'pictureBytes': 0,
        }),
      );

  @override
  ValueListenable<bool> registeredServiceListenable(String name) {
    if (availableServices.contains(name)) {
      return ImmediateValueNotifier(true);
    }
    return ImmediateValueNotifier(false);
  }

  @override
  bool libraryUriAvailableNow(String? uri) {
    return availableLibraries.any((u) => u.startsWith(uri!));
  }

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
      }),
    );
  }

  @override
  Future<void> sendDwdsEvent({
    required String screen,
    required String action,
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
    hasConnection = value;
    _connectedState.value =
        ConnectedState(value, userInitiatedConnectionState: manual);
  }

  @override
  ValueListenable<bool> get deviceBusy => ValueNotifier(false);
}

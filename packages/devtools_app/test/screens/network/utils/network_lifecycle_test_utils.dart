// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'hot_restart_network_vm_service.dart';

Future<NetworkController> initNetworkLifecycleController({
  required HotRestartNetworkVmService vmService,
  required FakeServiceConnectionManager fakeServiceConnection,
  List<HttpProfileRequest>? initialProfile,
}) async {
  if (initialProfile != null) {
    vmService.setHttpProfile(vmService.currentIsolateId, initialProfile);
  }
  final controller = setUpNetworkLifecycleController(fakeServiceConnection);
  await pumpEventQueue();
  return controller;
}

NetworkController setUpNetworkLifecycleController(
  FakeServiceConnectionManager fakeServiceConnection,
) {
  setGlobal(OfflineDataController, OfflineDataController());
  setGlobal(ScreenControllers, ScreenControllers());
  setGlobal(ServiceConnectionManager, fakeServiceConnection);
  setGlobal(PreferencesController, PreferencesController());
  screenControllers.register<NetworkController>(() => NetworkController());
  return screenControllers.lookup<NetworkController>();
}

void notifyMainIsolateChanged(
  FakeServiceConnectionManager connection,
  String newIsolateId,
) {
  final isolateManager =
      connection.serviceManager.isolateManager as FakeIsolateManager;
  final isolateRef = IsolateRef.parse({'id': newIsolateId, 'name': 'main'})!;
  (isolateManager.mainIsolate as ValueNotifier<IsolateRef?>).value = isolateRef;
  isolateManager.notifyIsolateCreated(isolateRef);
}

void disposeNetworkLifecycleControllers() {
  screenControllers.disposeConnectedControllers();
}

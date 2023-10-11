// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/service_extensions.dart' as extensions;
import 'package:devtools_shared/service.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

void main() async {
  final serviceManager = ServiceManager();

  // Example: use [connectedState] to listen for connection updates.
  serviceManager.connectedState.addListener(() {
    if (serviceManager.connectedState.value.connected) {
      print('Manager connected to VM service');
    } else {
      print('Manager not connected to VM service');
    }
  });

  // Example: establish a vm service connection.
  // To get a [VmService] object from a vm service URI, consider importing
  // `package:devtools_shared/service.dart` from `package:devtools_shared`.
  const someVmServiceUri = 'http://127.0.0.1:60851/fH-kAEXc7MQ=/';
  final finishedCompleter = Completer<void>();
  final vmService = await connect<VmService>(
    uri: Uri.parse(someVmServiceUri),
    finishedCompleter: finishedCompleter,
    createService: ({
      // ignore: avoid-dynamic, code needs to match API from VmService.
      required Stream<dynamic> /*String|List<int>*/ inStream,
      required void Function(String message) writeMessage,
      required Uri connectedUri,
    }) {
      return VmService(inStream, writeMessage);
    },
  );

  await serviceManager.vmServiceOpened(
    vmService,
    onClosed: finishedCompleter.future,
  );

  /// Example: Get a service extension state.
  final ValueListenable<ServiceExtensionState> performanceOverlayEnabled =
      serviceManager.serviceExtensionManager.getServiceExtensionState(
    extensions.performanceOverlay.extension,
  );

  // Example: Set a service extension state.
  await serviceManager.serviceExtensionManager.setServiceExtensionState(
    extensions.performanceOverlay.extension,
    enabled: true,
    value: true,
  );

  // Example: Access isolates.
  final myIsolate = serviceManager.isolateManager.mainIsolate.value;

  // Etc.
}

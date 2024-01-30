// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:stager/stager.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_data/cpu_profiler/cpu_profile.dart';

/// To run:
/// flutter run -t test/test_infra/scenes/cpu_profiler/default.stager_app.g.dart -d macos
class CpuProfilerDefaultScene extends Scene {
  late ProfilerScreenController controller;
  late FakeServiceConnectionManager fakeServiceConnection;
  late ProfilerScreen screen;

  @override
  Widget build(BuildContext context) {
    return wrapWithControllers(
      const ProfilerScreenBody(),
      profiler: controller,
    );
  }

  @override
  Future<void> setUp() async {
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(BannerMessagesController, BannerMessagesController());

    fakeServiceConnection = FakeServiceConnectionManager(
      service: FakeServiceManager.createFakeService(
        cpuSamples: CpuSamples.parse(goldenCpuSamplesJson),
      ),
    );
    final app = fakeServiceConnection.serviceManager.connectedApp!;
    mockConnectedApp(
      app,
      isFlutterApp: false,
      isProfileBuild: false,
      isWebApp: false,
    );
    when(fakeServiceConnection.errorBadgeManager.errorCountNotifier('profiler'))
        .thenReturn(ValueNotifier<int>(0));
    setGlobal(ServiceConnectionManager, fakeServiceConnection);

    final mockScriptManager = MockScriptManager();
    when(mockScriptManager.scriptRefForUri(any)).thenReturn(
      ScriptRef(
        uri: 'package:test/script.dart',
        id: 'script.dart',
      ),
    );
    when(mockScriptManager.sortedScripts).thenReturn(
      ValueNotifier<List<ScriptRef>>([]),
    );
    setGlobal(ScriptManager, mockScriptManager);

    controller = ProfilerScreenController();

    // Await a small delay to allow the ProfilerScreenController to complete
    // initialization.
    await Future.delayed(const Duration(seconds: 1));

    screen = ProfilerScreen();
  }

  @override
  String get title => '$CpuProfilerDefaultScene';
}

// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/connected_app.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/vm_service_wrapper.dart';
import 'package:mockito/mockito.dart';

// A mock of the serviceManager with enough mocked out to run the InfoController.
// TODO(djshuckerow): Directly mock the InfoController to make testing easier.
class MockServiceManager extends Mock implements ServiceConnectionManager {
  @override
  final VmServiceWrapper service = MockVmService();

  @override
  final ConnectedApp connectedApp = MockConnectedApp();
}

class MockVmService extends Mock implements VmServiceWrapper {}

class MockConnectedApp extends Mock implements ConnectedApp {}

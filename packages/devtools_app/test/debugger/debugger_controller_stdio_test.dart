// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = createMockVmServiceWrapperWithDefaults();

  final manager = FakeServiceManager(service: service);
  setGlobal(ServiceConnectionManager, manager);
  manager.consoleService.ensureServiceInitialized();

  setUp(() {
    serviceManager.consoleService.clearStdio();
  });

  test('ignores trailing new lines', () {
    serviceManager.consoleService.appendStdio('1\n');
    expect(serviceManager.consoleService.stdio.value.length, 1);
  });

  test('has an item for each line', () {
    serviceManager.consoleService
      ..appendStdio('1\n')
      ..appendStdio('2\n')
      ..appendStdio('3\n')
      ..appendStdio('4\n');
    expect(serviceManager.consoleService.stdio.value.length, 4);
  });

  test('preserves additional newlines', () {
    serviceManager.consoleService
      ..appendStdio('1\n\n')
      ..appendStdio('2\n\n')
      ..appendStdio('3\n\n')
      ..appendStdio('4\n\n');
    expect(serviceManager.consoleService.stdio.value.length, 8);
  });
}

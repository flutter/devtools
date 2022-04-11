// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/service/vm_service_wrapper.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

// See https://github.com/dart-lang/mockito/blob/master/NULL_SAFETY_README.md.
import 'vm_service_private_test.mocks.dart';

@GenerateMocks([VmServiceWrapper])
void main() {
  test('Ensure private RPCs can only be enabled with VM Developer Mode enabled',
      () async {
    final service = MockVmServiceWrapper();
    when(service.trackFuture(any, any)).thenAnswer(
      (invocation) => invocation.positionalArguments[1],
    );
    when(service.callMethod(argThat(equals('_collectAllGarbage')))).thenAnswer(
      (_) => Future.value(Success()),
    );
    when(service.onDebugEvent).thenAnswer((_) {
      return const Stream.empty();
    });
    when(service.onVMEvent).thenAnswer((_) {
      return const Stream.empty();
    });
    when(service.onIsolateEvent).thenAnswer((_) {
      return const Stream.empty();
    });
    when(service.onStdoutEvent).thenAnswer((_) {
      return const Stream.empty();
    });
    when(service.onStderrEvent).thenAnswer((_) {
      return const Stream.empty();
    });

    final fakeServiceManager = FakeServiceManager(
      service: VmServiceWrapper(service!, Uri()),
    );
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    VmServicePrivate.enablePrivateRpcs = false;
    try {
      await fakeServiceManager.service!.collectAllGarbage();
      fail('Should not be able to invoke private RPCs');
    } on StateError {
      /* expected */
    }

    VmServicePrivate.enablePrivateRpcs = true;
    try {
      await fakeServiceManager.service!.collectAllGarbage();
    } on StateError {
      fail('Should be able to invoke private RPCs');
    }
  });
}

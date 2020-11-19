import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/vm_service_wrapper.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';

void main() {
  test('Ensure private RPCs can only be enabled with VM Developer Mode enabled',
      () async {
    final service = MockVmService();
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

    final fakeServiceManager = FakeServiceManager(service: service);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    VmServicePrivate.enablePrivateRpcs = false;
    try {
      await fakeServiceManager.service.collectAllGarbage();
      fail('Should not be able to invoke private RPCs');
    } on StateError {
      /* expected */
    }

    VmServicePrivate.enablePrivateRpcs = true;
    try {
      await fakeServiceManager.service.collectAllGarbage();
    } on StateError {
      fail('Should be able to invoke private RPCs');
    }
  });
}

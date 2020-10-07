import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/vm_service_wrapper.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';

void main() {
  FakeServiceManager fakeServiceManager;

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    setGlobal(ServiceConnectionManager, fakeServiceManager);
  });

  test('Ensure private RPCs can only be enabled with VM Developer Mode enabled',
      () async {
    // ignore: unnecessary_cast
    when(fakeServiceManager.service.trackFuture as Function).thenReturn(
      <T>(String _, Future<T> future) => future,
    );
    when(fakeServiceManager.service
            .callMethod(argThat(equals('_collectAllGarbage'))))
        .thenAnswer(
      (_) => Future.value(Success()),
    );
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

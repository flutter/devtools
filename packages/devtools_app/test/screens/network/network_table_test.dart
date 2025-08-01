// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/test_data/network.dart';

import 'utils/network_test_utils.dart';

void main() {
  group('NetworkScreen NetworkRequestsTable', () {
    late NetworkController controller;
    late CurrentNetworkRequests currentRequests;
    late FakeServiceConnectionManager fakeServiceConnection;
    late SocketProfile socketProfile;
    late HttpProfile httpProfile;
    late List<NetworkRequest> requests;

    setUpAll(() {
      setGlobal(OfflineDataController, OfflineDataController());
      httpProfile = loadHttpProfile();
      socketProfile = loadSocketProfile();
      fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          httpProfile: httpProfile,
          socketProfile: socketProfile,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(IdeTheme, IdeTheme());

      // Bypass controller recording so timelineMicroOffset is not time dependant
      controller = NetworkController();
      currentRequests = CurrentNetworkRequests();
      controller.processNetworkTrafficHelper(
        socketProfile.sockets,
        httpProfile.requests,
        0,
        currentRequests: currentRequests,
      );
      requests = currentRequests.value;
    });

    DartIOHttpRequestData findRequestById(String id) {
      return requests.whereType<DartIOHttpRequestData>().firstWhere(
        (request) => request.id == id,
      );
    }

    test('UriColumn', () {
      final column = AddressColumn();
      for (final request in requests) {
        expect(column.getDisplayValue(request), request.uri.toString());
      }
    });

    test('MethodColumn', () {
      const column = MethodColumn();
      for (final request in requests) {
        expect(column.getDisplayValue(request), request.method);
      }
    });

    test('StatusColumn for http request', () {
      const column = StatusColumn();
      final getRequest = findRequestById('1');
      expect(column.getDisplayValue(getRequest), httpGet.status);

      final pendingRequest = findRequestById('7');
      expect(column.getDisplayValue(pendingRequest), '--');
    });

    test('TypeColumn for http request', () {
      const column = TypeColumn();
      final getRequest = findRequestById('1');

      expect(column.getDisplayValue(getRequest), 'json');
    });

    test('DurationColumn for http request', () {
      const column = DurationColumn();
      final getRequest = findRequestById('1');

      expect(column.getDisplayValue(getRequest), '811 ms');

      final pendingRequest = findRequestById('7');
      expect(column.getDisplayValue(pendingRequest), 'Pending');
    });

    test('TimestampColumn', () {
      final column = TimestampColumn();
      final getRequest = findRequestById('1');

      // The hours field may be unreliable since it depends on the timezone the
      // test is running in.
      expect(column.getDisplayValue(getRequest), contains(':45:26.279'));
    });
  });
}

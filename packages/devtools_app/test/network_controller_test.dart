// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/network/http_request_data.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';
import 'support/utils.dart';

void main() {
  group(
    'NetworkController',
    () {
      NetworkController controller;
      FakeServiceManager fakeServiceManager;
      Timeline timeline;

      setUpAll(
        () async {
          const testDataPath =
              '../devtools_testing/lib/support/http_request_timeline_test_data.json';
          final httpTestData = jsonDecode(
            await File(testDataPath).readAsString(),
          );
          timeline = Timeline.parse(httpTestData);
        },
      );

      setUp(
        () {
          fakeServiceManager = FakeServiceManager(
            useFakeService: true,
            timelineData: timeline,
          );
          setGlobal(ServiceConnectionManager, fakeServiceManager);
          controller = NetworkController();
        },
      );

      test(
        'initialize recording state',
        () async {
          expect(
            controller.isPolling,
            false,
          );

          // Fake service pretends HTTP timeline logging is always enabled.
          await controller.initialize();
          expect(
            controller.isPolling,
            true,
          );
        },
      );

      test(
        'start and pause recording',
        () async {
          expect(
            controller.isPolling,
            false,
          );
          final notifier = controller.recordingNotifier;
          await addListenerScope(
            notifier,
            () {
              expect(notifier.value, true);
              expect(
                controller.isPolling,
                true,
              );
            },
            () async => await controller.startRecording(),
          );

          await addListenerScope(
            notifier,
            () {
              expect(
                notifier.value,
                false,
              );
              expect(
                controller.isPolling,
                false,
              );
            },
            () async => await controller.pauseRecording(),
          );

          await addListenerScope(
            notifier,
            () {
              expect(
                notifier.value,
                true,
              );
              expect(
                controller.isPolling,
                true,
              );
            },
            () async => await controller.startRecording(),
          );

          await addListenerScope(
            notifier,
            () {
              expect(
                notifier.value,
                false,
              );
              expect(
                controller.isPolling,
                false,
              );
            },
            () => controller.dispose(),
          );
        },
      );

      test(
        'process HTTP timeline events',
        () async {
          await controller.initialize();
          final notifier = controller.requestsNotifier;
          HttpRequests profile = notifier.value;
          // Check profile is initially empty.
          expect(
            profile.requests.isEmpty,
            true,
          );
          expect(
            profile.outstandingRequests.isEmpty,
            true,
          );

          // The number of requests recorded in the test data.
          const numRequests = 70;

          // Force a refresh of the HTTP requests. Ensure there's requests populated.
          await addListenerScope(
            notifier,
            () {
              profile = notifier.value;
              expect(
                profile.requests.length,
                numRequests,
              );
              expect(
                profile.outstandingRequests.isEmpty,
                true,
              );

              const httpMethods = <String>{
                'CONNECT',
                'DELETE',
                'GET',
                'HEAD',
                'PATCH',
                'POST',
                'PUT',
              };

              for (final request in profile.requests) {
                expect(request.duration, isNotNull);
                expect(request.general, isNotNull);
                expect(request.general.length, greaterThan(0));
                expect(request.hasCookies, isNotNull);
                expect(request.inProgress, false);
                expect(request.instantEvents, isNotNull);
                expect(httpMethods.contains(request.method), true);
                expect(request.name, isNotNull);
                expect(request.requestCookies, isNotNull);
                expect(request.responseCookies, isNotNull);
                expect(request.requestTime, isNotNull);
                expect(request.status, isNotNull);
                expect(request.uri, isNotNull);
              }
            },
            () async => await controller.networkService.refreshHttpRequests(),
          );

          // Finally, call `clear()` and ensure the requests have been cleared.
          await addListenerScope(
            notifier,
            () {
              profile = notifier.value;
              expect(
                profile.requests.isEmpty,
                true,
              );
              expect(
                profile.outstandingRequests.isEmpty,
                true,
              );
            },
            () async => await controller.clear(),
          );
        },
      );
    },
  );
}

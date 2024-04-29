// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/network/network_request_inspector.dart';
import 'package:devtools_app/src/screens/network/network_request_inspector_views.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/network.dart';
import '../test_infra/utils/test_utils.dart';

void main() {
  group('NetworkRequestInspector', () {
    late NetworkController controller;
    late FakeServiceConnectionManager fakeServiceConnection;
    final HttpProfileRequest? httpRequest =
        HttpProfileRequest.parse(httpPostJson);
    String clipboardContents = '';

    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      clipboardContents = '';
      fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          httpProfile: HttpProfile(
            requests: [
              httpRequest!,
            ],
            timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
          ),
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(NotificationService, NotificationService());
      controller = NetworkController();
      setupClipboardCopyListener(
        clipboardContentsCallback: (contents) {
          clipboardContents = contents ?? '';
        },
      );
    });

    testWidgets('copy request body', (tester) async {
      final requestsNotifier = controller.requests;

      await controller.startRecording();

      await tester.pumpWidget(
        wrapWithControllers(
          NetworkRequestInspector(controller),
          debugger: createMockDebuggerControllerWithDefaults(),
        ),
      );

      // Load the network request.
      await controller.networkService.refreshNetworkData();
      expect(requestsNotifier.value.length, equals(1));

      // Select the request in the network request list.
      final networkRequest = requestsNotifier.value.first;
      controller.selectedRequest.value = networkRequest;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request'));
      await tester.pumpAndSettle();

      // Tap the requestBody copy button.
      expect(clipboardContents, isEmpty);
      await tester.tap(find.byType(CopyToClipboardControl));
      final expectedResponseBody =
          jsonDecode(utf8.decode(httpRequest!.requestBody!.toList()));

      // Check that the contents were copied to clipboard.
      expect(clipboardContents, isNotEmpty);
      expect(
        jsonDecode(clipboardContents),
        equals(expectedResponseBody),
      );

      await controller.stopRecording();

      // pumpAndSettle so residual http timers can clear.
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('copy response body', (tester) async {
      final requestsNotifier = controller.requests;

      await controller.startRecording();

      await tester.pumpWidget(
        wrapWithControllers(
          NetworkRequestInspector(controller),
          debugger: createMockDebuggerControllerWithDefaults(),
        ),
      );

      // Load the network request.
      await controller.networkService.refreshNetworkData();
      expect(requestsNotifier.value.length, equals(1));

      // Select the request in the network request list.
      final networkRequest = requestsNotifier.value.first;
      controller.selectedRequest.value = networkRequest;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Response'));
      await tester.pumpAndSettle();

      // Tap the responseBody copy button.
      expect(clipboardContents, isEmpty);
      await tester.tap(find.byType(CopyToClipboardControl));
      final expectedResponseBody =
          jsonDecode(utf8.decode(httpRequest!.responseBody!.toList()));

      // Check that the contents were copied to clipboard.
      expect(clipboardContents, isNotEmpty);
      expect(
        jsonDecode(clipboardContents),
        equals(expectedResponseBody),
      );

      await controller.stopRecording();

      // pumpAndSettle so residual http timers can clear.
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    group('HttpResponseTrailingDropDown', () {
      testWidgets(
        'drop down value should update when response view type changes',
        (tester) async {
          NetworkResponseViewType? getCurrentDropDownValue() {
            final RoundedDropDownButton<NetworkResponseViewType>
                dropDownWidget = find
                    .byType(RoundedDropDownButton<NetworkResponseViewType>)
                    .evaluate()
                    .first
                    .widget as RoundedDropDownButton<NetworkResponseViewType>;
            return dropDownWidget.value;
          }

          final currentResponseViewType =
              ValueNotifier<NetworkResponseViewType>(
            NetworkResponseViewType.auto,
          );

          // Matches Drop Down value with currentResponseViewType
          void checkDropDownValue() {
            final currentDropDownValue = getCurrentDropDownValue();
            expect(currentDropDownValue, equals(currentResponseViewType.value));
          }

          await tester.pumpWidget(
            wrapWithControllers(
              HttpResponseTrailingDropDown(
                httpGet,
                currentResponseViewType: currentResponseViewType,
                onChanged: (value) {
                  currentResponseViewType.value = value;
                },
              ),
              debugger: createMockDebuggerControllerWithDefaults(),
            ),
          );

          await tester.pumpAndSettle();
          checkDropDownValue();

          currentResponseViewType.value = NetworkResponseViewType.text;
          await tester.pumpAndSettle();
          checkDropDownValue();

          currentResponseViewType.value = NetworkResponseViewType.auto;
          await tester.pumpAndSettle();
          checkDropDownValue();

          // pumpAndSettle so residual http timers can clear.
          await tester.pumpAndSettle(const Duration(seconds: 1));
        },
      );

      testWidgets(
        'onChanged handler should trigger when changing drop down value',
        (tester) async {
          final currentResponseViewType =
              ValueNotifier<NetworkResponseViewType>(
            NetworkResponseViewType.auto,
          );
          String initial = 'Not changed';
          const String afterOnChanged = 'changed';

          await tester.pumpWidget(
            wrapWithControllers(
              HttpResponseTrailingDropDown(
                httpGet,
                currentResponseViewType: currentResponseViewType,
                onChanged: (value) {
                  initial = afterOnChanged;
                },
              ),
              debugger: createMockDebuggerControllerWithDefaults(),
            ),
          );

          final dropDownFinder = find.byType(
            RoundedDropDownButton<NetworkResponseViewType>,
          );

          await tester.tap(dropDownFinder);
          await tester.pumpAndSettle();

          // Select Json from drop down
          await tester.tap(
            find.text(
              NetworkResponseViewType.json.toString(),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            initial,
            afterOnChanged,
          );

          // pumpAndSettle so residual http timers can clear.
          await tester.pumpAndSettle(const Duration(seconds: 1));
        },
      );
    });

    testWidgets(
      'should update response view display when drop down value changes',
      (tester) async {
        final currentResponseNotifier = ValueNotifier<NetworkResponseViewType>(
          NetworkResponseViewType.auto,
        );
        const contentType = 'application/json';
        final responseBody = httpGet.requestBody ?? '{}';
        const textStyle = TextStyle();

        await tester.pumpWidget(
          wrapWithControllers(
            Column(
              children: [
                HttpTextResponseViewer(
                  contentType: contentType,
                  responseBody: responseBody,
                  currentResponseNotifier: currentResponseNotifier,
                  textStyle: textStyle,
                ),
                HttpResponseTrailingDropDown(
                  httpGet,
                  currentResponseViewType: currentResponseNotifier,
                  onChanged: (value) {},
                ),
              ],
            ),
            debugger: createMockDebuggerControllerWithDefaults(),
          ),
        );

        await tester.pumpAndSettle();

        currentResponseNotifier.value = NetworkResponseViewType.json;

        await tester.pumpAndSettle();

        // Check that Json viewer is visible
        Finder jsonViewer = find.byType(JsonViewer);
        expect(jsonViewer, findsOneWidget);

        currentResponseNotifier.value = NetworkResponseViewType.text;

        await tester.pumpAndSettle();

        // Check that Json viewer is not visible
        jsonViewer = find.byType(JsonViewer);
        expect(jsonViewer, findsNothing);

        // pumpAndSettle so residual http timers can clear.
        await tester.pumpAndSettle(const Duration(seconds: 1));
      },
    );
  });
}

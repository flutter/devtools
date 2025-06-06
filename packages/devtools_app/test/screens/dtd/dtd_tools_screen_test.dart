// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/dtd/events.dart';
import 'package:devtools_app/src/screens/dtd/services.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late DTDToolsScreen screen;
  late DTDToolsController dtdToolsController;
  late MockDTDManager mockGlobalDTDManager;
  const windowSize = Size(1500.0, 1500.0);

  group('$DTDToolsScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      DTDToolsController? controller,
    }) async {
      await tester.pumpWidget(
        wrapWithControllers(
          const DTDToolsScreenBody(),
          dtdTools: controller ?? dtdToolsController,
        ),
      );
    }

    setUp(() {
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());

      mockGlobalDTDManager = MockDTDManager();
      when(
        mockGlobalDTDManager.connection,
      ).thenReturn(const FixedValueListenable(null));
      setGlobal(DTDManager, mockGlobalDTDManager);
      dtdToolsController = DTDToolsController();
      screen = DTDToolsScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('DTD Tools'), findsOneWidget);
      expect(find.byIcon(Icons.settings_applications), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds with no DTD connection', windowSize, (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      expect(find.byType(DtdNotConnectedView), findsOneWidget);
      expect(find.byType(DtdConnectedView), findsNothing);
      expect(find.byType(ServicesView), findsNothing);
      expect(find.byType(EventsView), findsNothing);
    });

    testWidgetsWithWindowSize(
      'connects to existing connection by default but can connect to a different one',
      windowSize,
      (WidgetTester tester) async {
        // Set up [mockGlobalDTDManager].
        final mockGlobalDtd = MockDartToolingDaemon();
        final globalConnectionNotifier = ValueNotifier<DartToolingDaemon?>(
          mockGlobalDtd,
        );
        when(
          mockGlobalDTDManager.connection,
        ).thenReturn(globalConnectionNotifier);

        // Set up [mockGlobalDtd].
        when(mockGlobalDtd.getRegisteredServices()).thenAnswer((_) {
          return Future.value(
            const RegisteredServicesResponse(
              dtdServices: [],
              clientServices: [],
            ),
          );
        });

        // Set up mock [DTDToolsController].
        final dtdToolsController = MockDTDToolsController();
        final mockLocalDtdManager = MockDTDManager();
        final localConnectionNotifier = ValueNotifier<DartToolingDaemon?>(
          mockGlobalDtd,
        );
        when(
          dtdToolsController.localDtdManager,
        ).thenReturn(mockLocalDtdManager);

        // Set up [mockLocalDtdManager].
        final fakeDtdUri = Uri.parse('ws://127.0.0.1:65314/KKXNgPdXnFk=');
        final localDtdManagerUri = ValueNotifier<Uri?>(fakeDtdUri);
        when(
          mockLocalDtdManager.connection,
        ).thenReturn(localConnectionNotifier);
        when(mockLocalDtdManager.uri).thenReturn(localDtdManagerUri.value);
        when(mockLocalDtdManager.disconnect()).thenAnswer((_) {
          localConnectionNotifier.value = null;
          localDtdManagerUri.value = null;
          return Future.value();
        });
        final mockLocalDtd = MockDartToolingDaemon();
        when(mockLocalDtdManager.connect(any)).thenAnswer((_) {
          localConnectionNotifier.value = mockLocalDtd;
          localDtdManagerUri.value = fakeDtdUri;
          return Future.value();
        });

        // Set up [mockLocalDtd].
        when(mockLocalDtd.getRegisteredServices()).thenAnswer((_) {
          return Future.value(
            const RegisteredServicesResponse(
              dtdServices: [],
              clientServices: [],
            ),
          );
        });

        await pumpScreen(tester, controller: dtdToolsController);

        // Should be connected to the globally connected DTD on initial load.
        expect(find.byType(DtdNotConnectedView), findsNothing);
        expect(find.byType(DtdConnectedView), findsOneWidget);
        expect(mockLocalDtdManager.connection.value, mockGlobalDtd);

        final disconnectButtonFinder = find.text('Disconnect');
        expect(disconnectButtonFinder, findsOneWidget);
        await tester.tap(disconnectButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(DtdNotConnectedView), findsOneWidget);
        expect(find.byType(DtdConnectedView), findsNothing);
        expect(mockLocalDtdManager.connection.value, null);

        final textFieldFinder = find.byType(DevToolsClearableTextField);
        expect(textFieldFinder, findsOneWidget);
        await tester.enterText(textFieldFinder, 'foo'); // Text does not matter.
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        // Should now be connected to the locally connected DTD.
        expect(find.byType(DtdNotConnectedView), findsNothing);
        expect(find.byType(DtdConnectedView), findsOneWidget);
        expect(mockLocalDtdManager.connection.value, mockLocalDtd);
      },
    );
  });
}

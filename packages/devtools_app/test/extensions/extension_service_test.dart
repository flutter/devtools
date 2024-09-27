// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:devtools_app/src/shared/server/server.dart' as server;
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockServiceManager mockServiceManager;

  group('$ExtensionService', () {
    setUp(() {
      setTestMode();
      setGlobal(PreferencesController, PreferencesController());

      final mockServiceConnection = createMockServiceConnectionWithDefaults();
      mockServiceManager =
          mockServiceConnection.serviceManager as MockServiceManager;
      when(mockServiceManager.connectedState)
          .thenReturn(ValueNotifier(const ConnectedState(true)));
      setGlobal(ServiceConnectionManager, mockServiceConnection);
    });

    tearDown(() {
      resetDevToolsExtensionEnabledStates();
    });

    test('initialize when connected', () async {
      final service = ExtensionService(
        fixedAppRoot: Uri.parse('file:///Users/me/package_root_1'),
      );
      expect(service.availableExtensions, isEmpty);
      expect(service.staticExtensions, isEmpty);
      expect(service.runtimeExtensions, isEmpty);

      await service.initialize();
      expect(service.staticExtensions.length, 4);
      expect(service.runtimeExtensions.length, 3);
      expect(service.availableExtensions.length, 5);

      final ignoredStaticExtensions =
          service.staticExtensions.where(service.isExtensionIgnored);
      final ignoredRuntimeExtensions =
          service.runtimeExtensions.where(service.isExtensionIgnored);
      expect(ignoredStaticExtensions.length, 2);
      expect(ignoredStaticExtensions.map((e) => e.identifier).toList(), [
        'bar_2.0.0',
        'foo_1.0.0',
      ]);
      expect(ignoredRuntimeExtensions.length, 0);
    });

    test('initialize with ignoreServiceConnection', () async {
      when(mockServiceManager.connectedState)
          .thenReturn(ValueNotifier(const ConnectedState(false)));

      final service = ExtensionService(ignoreServiceConnection: true);
      expect(service.staticExtensions, isEmpty);
      expect(service.runtimeExtensions, isEmpty);
      expect(service.availableExtensions, isEmpty);

      await service.initialize();
      expect(service.staticExtensions.length, 4);
      expect(service.runtimeExtensions, isEmpty);
      expect(service.availableExtensions.length, 3);

      final ignoredStaticExtensions =
          service.staticExtensions.where(service.isExtensionIgnored);
      expect(ignoredStaticExtensions.length, 1);
      expect(ignoredStaticExtensions.map((e) => e.identifier).toList(), [
        'bar_2.0.0', // Duplicate: older version of an existing extension.
      ]);
    });

    test('setExtensionEnabledState', () async {
      final service = ExtensionService(
        fixedAppRoot: Uri.parse('file:///Users/me/package_root_1'),
      );
      await service.initialize();
      expect(service.staticExtensions.length, 4);
      expect(service.runtimeExtensions.length, 3);
      expect(service.availableExtensions.length, 5);

      Future<ExtensionEnabledState> enabledOnDisk(
        DevToolsExtensionConfig ext,
      ) async {
        return await server.extensionEnabledState(
          devtoolsOptionsFileUri: ext.devtoolsOptionsUri,
          extensionName: ext.name,
        );
      }

      var barEnabledState =
          await enabledOnDisk(StubDevToolsExtensions.barExtension);
      var newerBarEnabledState =
          await enabledOnDisk(StubDevToolsExtensions.newerBarExtension);
      expect(barEnabledState, ExtensionEnabledState.none);
      expect(newerBarEnabledState, ExtensionEnabledState.none);
      expect(
        service
            .enabledStateListenable(StubDevToolsExtensions.barExtension.name)
            .value,
        ExtensionEnabledState.none,
      );

      await service.setExtensionEnabledState(
        StubDevToolsExtensions.barExtension,
        enable: true,
      );

      // Verify enabled states for all matching extensions have been updated.
      barEnabledState =
          await enabledOnDisk(StubDevToolsExtensions.barExtension);
      newerBarEnabledState =
          await enabledOnDisk(StubDevToolsExtensions.newerBarExtension);
      expect(barEnabledState, ExtensionEnabledState.enabled);
      expect(newerBarEnabledState, ExtensionEnabledState.enabled);
      expect(
        service
            .enabledStateListenable(StubDevToolsExtensions.barExtension.name)
            .value,
        ExtensionEnabledState.enabled,
      );

      var fooEnabledState =
          await enabledOnDisk(StubDevToolsExtensions.fooExtension);
      var duplicateFooEnabledState =
          await enabledOnDisk(StubDevToolsExtensions.duplicateFooExtension);
      expect(fooEnabledState, ExtensionEnabledState.none);
      expect(duplicateFooEnabledState, ExtensionEnabledState.none);
      expect(
        service
            .enabledStateListenable(StubDevToolsExtensions.fooExtension.name)
            .value,
        ExtensionEnabledState.none,
      );

      await service.setExtensionEnabledState(
        StubDevToolsExtensions.duplicateFooExtension,
        enable: false,
      );

      // Verify enabled states for all matching extensions have been updated.
      fooEnabledState =
          await enabledOnDisk(StubDevToolsExtensions.fooExtension);
      duplicateFooEnabledState =
          await enabledOnDisk(StubDevToolsExtensions.duplicateFooExtension);
      expect(fooEnabledState, ExtensionEnabledState.disabled);
      expect(duplicateFooEnabledState, ExtensionEnabledState.disabled);
      expect(
        service
            .enabledStateListenable(StubDevToolsExtensions.fooExtension.name)
            .value,
        ExtensionEnabledState.disabled,
      );
    });

    test('ignore behavior', () {
      final service = ExtensionService();
      final extensionsToIgnore = [
        StubDevToolsExtensions.barExtension,
        StubDevToolsExtensions.bazExtension,
        StubDevToolsExtensions.someToolExtension,
      ];
      for (final e in extensionsToIgnore) {
        service.setExtensionIgnored(e, ignore: true);
      }
      for (final ext in StubDevToolsExtensions.extensions()) {
        expect(
          service.isExtensionIgnored(ext),
          extensionsToIgnore.contains(ext),
        );
      }
      for (final ext in extensionsToIgnore) {
        service.setExtensionIgnored(ext, ignore: false);
      }
      for (final ext in StubDevToolsExtensions.extensions()) {
        expect(service.isExtensionIgnored(ext), false);
      }
    });
  });
}

// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  test('constants have expected values', () {
    expect(enableExperiments, false);
    expect(enableBeta, false);
    expect(isExternalBuild, true);
    expect(FeatureFlags.memorySaveLoad.isEnabled, false);
    expect(FeatureFlags.networkSaveLoad.isEnabled, true);
    expect(FeatureFlags.devToolsExtensions.isEnabled, isExternalBuild);
    expect(FeatureFlags.dapDebugging.isEnabled, false);
    expect(FeatureFlags.inspectorV2.isEnabled, true);
    expect(FeatureFlags.propertyEditorRefactors.isEnabled, true);
  });

  group('FlutterChannelFeatureFlag', () {
    final connectedApp = MockConnectedApp();

    late FlutterChannelFeatureFlag flag;

    setUp(() {
      final mockServiceConnection = createMockServiceConnectionWithDefaults();
      final mockServiceManager =
          mockServiceConnection.serviceManager as MockServiceManager;
      when(
        mockServiceManager.serviceExtensionManager,
      ).thenReturn(FakeServiceExtensionManager());
      when(mockServiceManager.connectedApp).thenReturn(connectedApp);
      setGlobal(ServiceConnectionManager, mockServiceConnection);
    });

    test('pure Dart app', () {
      mockConnectedApp(connectedApp, isFlutterApp: false);

      flag = const FlutterChannelFeatureFlag(
        name: 'test',
        flutterChannel: FlutterChannel.dev,
        enabledForDartApps: true,
        enabledForFlutterAppsFallback: false,
      );
      expect(flag.isEnabled(connectedApp), isTrue);

      flag = const FlutterChannelFeatureFlag(
        name: 'test',
        flutterChannel: FlutterChannel.dev,
        enabledForDartApps: false,
        enabledForFlutterAppsFallback: true,
      );
      expect(flag.isEnabled(connectedApp), isFalse);
    });

    test('Flutter app on an unknown version', () {
      mockConnectedApp(connectedApp, flutterVersion: 'unknown-version');

      flag = const FlutterChannelFeatureFlag(
        name: 'test',
        flutterChannel: FlutterChannel.dev,
        enabledForDartApps: false,
        enabledForFlutterAppsFallback: true,
      );
      expect(flag.isEnabled(connectedApp), isTrue);

      flag = const FlutterChannelFeatureFlag(
        name: 'test',
        flutterChannel: FlutterChannel.dev,
        enabledForDartApps: true,
        enabledForFlutterAppsFallback: false,
      );
      expect(flag.isEnabled(connectedApp), isFalse);
    });

    group('Flutter app with version', () {
      const stableVersion = '2.3.0';
      const betaVersion = '2.3.0-17.0.pre';
      const devVersion = '2.3.0-17.0.pre.355';

      void enableFeatureFlagForChannel(FlutterChannel channel) {
        flag = FlutterChannelFeatureFlag(
          name: 'test',
          flutterChannel: channel,
          enabledForDartApps: false,
          enabledForFlutterAppsFallback: false,
        );
      }

      void expectEnabledForChannels({
        required bool enabledOnStable,
        required bool enabledOnBeta,
        required bool enabledOnDev,
      }) {
        // Flutter app using stable channel.
        mockConnectedApp(connectedApp, flutterVersion: stableVersion);
        expect(flag.isEnabled(connectedApp), equals(enabledOnStable));

        // Flutter app using beta channel.
        mockConnectedApp(connectedApp, flutterVersion: betaVersion);
        expect(flag.isEnabled(connectedApp), equals(enabledOnBeta));

        // Flutter app using dev channel.
        mockConnectedApp(connectedApp, flutterVersion: devVersion);
        expect(flag.isEnabled(connectedApp), equals(enabledOnDev));
      }

      test('enabled on dev', () {
        enableFeatureFlagForChannel(FlutterChannel.dev);

        expectEnabledForChannels(
          enabledOnStable: false,
          enabledOnBeta: false,
          enabledOnDev: true,
        );
      });

      test('enabled on beta', () {
        enableFeatureFlagForChannel(FlutterChannel.beta);

        expectEnabledForChannels(
          enabledOnStable: false,
          enabledOnBeta: true,
          enabledOnDev: true,
        );
      });

      test('enabled on stable', () {
        enableFeatureFlagForChannel(FlutterChannel.stable);

        expectEnabledForChannels(
          enabledOnStable: true,
          enabledOnBeta: true,
          enabledOnDev: true,
        );
      });
    });
  });
}

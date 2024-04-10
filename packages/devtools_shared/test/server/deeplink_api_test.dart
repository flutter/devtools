// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/src/deeplink/deeplink_manager.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../fakes.dart';

void main() {
  group('$DeeplinkApi', () {
    test('handle deeplink api ${DeeplinkApi.androidBuildVariants}', () async {
      const expectedRootPath = '/abc';
      final request = Request(
        'get',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: DeeplinkApi.androidBuildVariants,
          queryParameters: <String, String>{
            DeeplinkApi.deeplinkRootPathPropertyName: expectedRootPath,
          },
        ),
      );
      final fakeManager = FakeDeeplinkManager();
      fakeManager.responseForGetAndroidBuildVariants = <String, String>{
        DeeplinkManager.kOutputJsonField: '["debug", "release]',
      };
      final response = await ServerApi.handle(
        request,
        extensionsManager: ExtensionsManager(),
        deeplinkManager: fakeManager,
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), '["debug", "release]');
      expect(fakeManager.receivedPath, expectedRootPath);
    });

    test(
      'handle deeplink api ${DeeplinkApi.androidBuildVariants} returns bad request if no root path',
      () async {
        final request = Request(
          'get',
          Uri(
            scheme: 'https',
            host: 'localhost',
            path: DeeplinkApi.androidBuildVariants,
          ),
        );
        final response = await ServerApi.handle(
          request,
          extensionsManager: ExtensionsManager(),
          deeplinkManager: FakeDeeplinkManager(),
        );
        expect(response.statusCode, HttpStatus.badRequest);
      },
    );

    test('handle deeplink api ${DeeplinkApi.androidAppLinkSettings}', () async {
      const expectedRootPath = '/abc';
      const buildVariant = 'buildVariant';
      const someMessage = 'some message';
      final request = Request(
        'get',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: DeeplinkApi.androidAppLinkSettings,
          queryParameters: <String, String>{
            DeeplinkApi.deeplinkRootPathPropertyName: expectedRootPath,
            DeeplinkApi.androidBuildVariantPropertyName: buildVariant,
          },
        ),
      );
      final fakeManager = FakeDeeplinkManager();
      fakeManager.responseForGetAndroidAppLinkSettings = <String, String>{
        DeeplinkManager.kOutputJsonField: someMessage,
      };
      final response = await ServerApi.handle(
        request,
        extensionsManager: ExtensionsManager(),
        deeplinkManager: fakeManager,
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), someMessage);
      expect(fakeManager.receivedPath, expectedRootPath);
      expect(fakeManager.receivedBuildVariant, buildVariant);
    });

    test('handle deeplink api ${DeeplinkApi.iosBuildOptions}', () async {
      const expectedRootPath = '/abc';
      const someMessage = 'some message';
      final request = Request(
        'get',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: DeeplinkApi.iosBuildOptions,
          queryParameters: <String, String>{
            DeeplinkApi.deeplinkRootPathPropertyName: expectedRootPath,
          },
        ),
      );
      final fakeManager = FakeDeeplinkManager();
      fakeManager.responseForGetIosBuildOptions = <String, String>{
        DeeplinkManager.kOutputJsonField: someMessage,
      };
      final response = await ServerApi.handle(
        request,
        extensionsManager: ExtensionsManager(),
        deeplinkManager: fakeManager,
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), someMessage);
      expect(fakeManager.receivedPath, expectedRootPath);
    });

    test(
      'handle deeplink api ${DeeplinkApi.iosUniversalLinkSettings}',
      () async {
        const expectedRootPath = '/abc';
        const configuration = 'configuration';
        const target = 'target';
        const someMessage = 'some message';
        final request = Request(
          'get',
          Uri(
            scheme: 'https',
            host: 'localhost',
            path: DeeplinkApi.iosUniversalLinkSettings,
            queryParameters: <String, String>{
              DeeplinkApi.deeplinkRootPathPropertyName: expectedRootPath,
              DeeplinkApi.xcodeConfigurationPropertyName: configuration,
              DeeplinkApi.xcodeTargetPropertyName: target,
            },
          ),
        );
        final fakeManager = FakeDeeplinkManager();
        fakeManager.responseForGetIosUniversalLinkSettings = <String, String>{
          DeeplinkManager.kOutputJsonField: someMessage,
        };
        final response = await ServerApi.handle(
          request,
          extensionsManager: ExtensionsManager(),
          deeplinkManager: fakeManager,
        );
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), someMessage);
        expect(fakeManager.receivedConfiguration, configuration);
        expect(fakeManager.receivedTarget, target);
      },
    );
  });
}

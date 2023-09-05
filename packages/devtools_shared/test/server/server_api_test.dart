// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/src/deeplink/deeplink_manager.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('handle deeplink api', () async {
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
    fakeManager.responseForGetBuildVariants = <String, String>{
      DeeplinkManager.kOutputJsonField: '["debug", "release]',
    };
    final response = await ServerApi.handle(
      request,
      extensionsManager: ExtensionsManager(buildDir: '/'),
      deeplinkManager: fakeManager,
    );
    expect(response.statusCode, HttpStatus.ok);
    expect(await response.readAsString(), '["debug", "release]');
  });

  test('handle deeplink api returns bad request if no root path', () async {
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
      extensionsManager: ExtensionsManager(buildDir: '/'),
      deeplinkManager: FakeDeeplinkManager(),
    );
    expect(response.statusCode, HttpStatus.badRequest);
  });
}

class FakeDeeplinkManager extends DeeplinkManager {
  String? receivedPathFromGetBuildVariants;
  late Map<String, String> responseForGetBuildVariants;

  @override
  Future<Map<String, String>> getBuildVariants({
    required String rootPath,
  }) async {
    receivedPathFromGetBuildVariants = rootPath;
    return responseForGetBuildVariants;
  }
}

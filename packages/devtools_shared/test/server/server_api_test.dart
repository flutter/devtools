// Copyright 2022 The Chromium Authors. All rights reserved.
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
    final expectedResponse = Response(HttpStatus.ok);
    fakeManager.responseForGetBuildVariants = expectedResponse;
    final response = await ServerApi.handle(request, ExtensionsManager(buildDir: '/'), fakeManager);
    expect(response, expectedResponse);
    expect(fakeManager.receivedPathFromGetBuildVariants, expectedRootPath);
  });

  test('handle deeplink api returns bad request if no root path', () async {
    const expectedRootPath = '/abc';
    final request = Request(
      'get',
      Uri(
        scheme: 'https',
        host: 'localhost',
        path: DeeplinkApi.androidBuildVariants,
      ),
    );
    final response = await ServerApi.handle(request, ExtensionsManager(buildDir: '/'), FakeDeeplinkManager());
    expect(response.statusCode, HttpStatus.badRequest);
  });
}

class FakeDeeplinkManager extends DeeplinkManager {
  String? receivedPathFromGetBuildVariants;
  late Response responseForGetBuildVariants;

  @override
  Future<Response> getBuildVariants({
    required String rootPath,
    required ServerApi api,
  }) async {
    receivedPathFromGetBuildVariants = rootPath;
    return responseForGetBuildVariants;
  }
}
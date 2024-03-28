// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../fakes.dart';

void main() {
  group('$DtdApi', () {
    test('handle ${DtdApi.apiGetDtdUri} succeeds', () async {
      const dtdUri = 'ws://dtd:uri';
      final request = Request(
        'get',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: DtdApi.apiGetDtdUri,
        ),
      );
      final response = await ServerApi.handle(
        request,
        extensionsManager: ExtensionsManager(buildDir: '/'),
        deeplinkManager: FakeDeeplinkManager(),
        dtd: (uri: dtdUri, secret: null),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(
        await response.readAsString(),
        jsonEncode({DtdApi.uriPropertyName: dtdUri}),
      );
    });
  });
}

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_shared/devtools_server.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/src/devtools_api.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart' as server;
import 'package:dtd/dtd.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:unified_analytics/unified_analytics.dart';

import '../fakes.dart';
import '../helpers.dart';

void main() {
  group('General DevTools server API', () {
    group(apiNotifyForVmServiceConnection, () {
      test(
        'succeeds when DTD is not available',
        () async {
          final request = Request(
            'get',
            Uri(
              scheme: 'https',
              host: 'localhost',
              path: apiNotifyForVmServiceConnection,
              queryParameters: {
                apiParameterValueKey: 'fake_uri',
                apiParameterVmServiceConnected: 'true',
              },
            ),
          );
          final response = await server.ServerApi.handle(
            request,
            extensionsManager: ExtensionsManager(buildDir: '/'),
            deeplinkManager: FakeDeeplinkManager(),
            dtd: (uri: null, secret: null),
            analytics: const NoOpAnalytics(),
          );
          expect(response.statusCode, HttpStatus.ok);
          expect(await response.readAsString(), isEmpty);
        },
      );

      test(
        'returns badRequest for invalid VM service argument',
        () async {
          final request = Request(
            'get',
            Uri(
              scheme: 'https',
              host: 'localhost',
              path: apiNotifyForVmServiceConnection,
              queryParameters: {
                apiParameterValueKey: 'fake_uri',
                apiParameterVmServiceConnected: 'true',
              },
            ),
          );
          final response = await server.ServerApi.handle(
            request,
            extensionsManager: ExtensionsManager(buildDir: '/'),
            deeplinkManager: FakeDeeplinkManager(),
            dtd: (uri: 'ws://dtd:uri', secret: 'fake_secret'),
            analytics: const NoOpAnalytics(),
          );
          expect(response.statusCode, HttpStatus.badRequest);
          final respasString = await response.readAsString();
          expect(
            respasString,
            contains('Cannot normalize VM service URI'),
          );
        },
      );
      test(
        'returns badRequest for invalid $apiParameterVmServiceConnected argument',
        () async {
          final request = Request(
            'get',
            Uri(
              scheme: 'https',
              host: 'localhost',
              path: apiNotifyForVmServiceConnection,
              queryParameters: {
                apiParameterValueKey: 'ws://127.0.0.1:8181/LEpVqqD7E_Y=/ws',
                apiParameterVmServiceConnected: 'bad_arg',
              },
            ),
          );
          final response = await server.ServerApi.handle(
            request,
            extensionsManager: ExtensionsManager(buildDir: '/'),
            deeplinkManager: FakeDeeplinkManager(),
            dtd: (uri: 'ws://dtd:uri', secret: 'fake_secret'),
            analytics: const NoOpAnalytics(),
          );
          expect(response.statusCode, HttpStatus.badRequest);
          expect(
            await response.readAsString(),
            contains('Cannot parse $apiParameterVmServiceConnected parameter'),
          );
        },
      );
    });

    group('updateDtdWorkspaceRoots', () {
      TestDtdConnectionInfo? dtd;
      DTDConnection? testDtdConnection;

      setUp(() async {
        dtd = await startDtd();
        testDtdConnection =
            await DartToolingDaemon.connect(Uri.parse(dtd!.uri!));
      });

      tearDown(() async {
        await testDtdConnection?.close();
        dtd?.dtdProcess?.kill();
        await dtd?.dtdProcess?.exitCode;
        dtd = null;
      });

      test('adds and removes workspace roots', () async {
        var currentRoots =
            (await testDtdConnection!.getIDEWorkspaceRoots()).ideWorkspaceRoots;
        expect(currentRoots, isEmpty);

        final rootUri1 = Uri.parse('file:///Users/me/package_root_1');
        final rootUri2 = Uri.parse('file:///Users/me/package_root_2');

        await server.Handler.updateDtdWorkspaceRoots(
          (uri: dtd!.uri, secret: dtd!.secret),
          rootFromVmService: rootUri1,
          connected: true,
          api: ServerApi(),
        );
        currentRoots =
            (await testDtdConnection!.getIDEWorkspaceRoots()).ideWorkspaceRoots;
        expect(currentRoots, hasLength(1));
        expect(currentRoots, contains(rootUri1));

        // Add a second root and verify the roots are unioned.
        await server.Handler.updateDtdWorkspaceRoots(
          (uri: dtd!.uri, secret: dtd!.secret),
          rootFromVmService: rootUri2,
          connected: true,
          api: ServerApi(),
        );
        currentRoots =
            (await testDtdConnection!.getIDEWorkspaceRoots()).ideWorkspaceRoots;
        expect(currentRoots, hasLength(2));
        expect(currentRoots, contains(rootUri1));
        expect(currentRoots, contains(rootUri2));

        // Verify duplicates cannot be added.
        await server.Handler.updateDtdWorkspaceRoots(
          (uri: dtd!.uri, secret: dtd!.secret),
          rootFromVmService: rootUri2,
          connected: true,
          api: ServerApi(),
        );
        currentRoots =
            (await testDtdConnection!.getIDEWorkspaceRoots()).ideWorkspaceRoots;
        expect(currentRoots, hasLength(2));
        expect(currentRoots, contains(rootUri1));
        expect(currentRoots, contains(rootUri2));

        // Verify roots are removed for diconnect events.
        await server.Handler.updateDtdWorkspaceRoots(
          (uri: dtd!.uri, secret: dtd!.secret),
          rootFromVmService: rootUri2,
          connected: false,
          api: ServerApi(),
        );
        currentRoots =
            (await testDtdConnection!.getIDEWorkspaceRoots()).ideWorkspaceRoots;
        expect(currentRoots, hasLength(1));
        expect(currentRoots, contains(rootUri1));

        await server.Handler.updateDtdWorkspaceRoots(
          (uri: dtd!.uri, secret: dtd!.secret),
          rootFromVmService: rootUri1,
          connected: false,
          api: ServerApi(),
        );
        currentRoots =
            (await testDtdConnection!.getIDEWorkspaceRoots()).ideWorkspaceRoots;
        expect(currentRoots, isEmpty);
      });
    });

    // TODO(kenz): find a way to test the functionality of connecting to a real
    // VM service here to get the root library.
  });
}

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_shared/devtools_server.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart' as server;
import 'package:dtd/dtd.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../fakes.dart';
import '../helpers.dart';

void main() {
  group('General DevTools server API', () {
    group(apiNotifyForVmServiceConnection, () {
      Future<Response> sendNotifyRequest({
        required DTDConnectionInfo dtd,
        Map<String, Object?>? queryParameters,
      }) async {
        final request = Request(
          'get',
          Uri(
            scheme: 'https',
            host: 'localhost',
            path: apiNotifyForVmServiceConnection,
            queryParameters: queryParameters,
          ),
        );
        return server.ServerApi.handle(
          request,
          extensionsManager: ExtensionsManager(),
          deeplinkManager: FakeDeeplinkManager(),
          dtd: dtd,
        );
      }

      test(
        'succeeds when DTD is not available',
        () async {
          final response = await sendNotifyRequest(
            dtd: (uri: null, secret: null),
            queryParameters: {
              apiParameterValueKey: 'fake_uri',
              apiParameterVmServiceConnected: 'true',
            },
          );
          expect(response.statusCode, HttpStatus.ok);
          expect(await response.readAsString(), isEmpty);
        },
      );

      test(
        'returns badRequest for invalid VM service argument',
        () async {
          final response = await sendNotifyRequest(
            dtd: (uri: 'ws://dtd:uri', secret: 'fake_secret'),
            queryParameters: {
              apiParameterValueKey: 'fake_uri',
              apiParameterVmServiceConnected: 'true',
            },
          );
          expect(response.statusCode, HttpStatus.badRequest);
          expect(
            await response.readAsString(),
            contains('Cannot normalize VM service URI'),
          );
        },
      );
      test(
        'returns badRequest for invalid $apiParameterVmServiceConnected argument',
        () async {
          final response = await sendNotifyRequest(
            dtd: (uri: 'ws://dtd:uri', secret: 'fake_secret'),
            queryParameters: {
              apiParameterValueKey: 'ws://127.0.0.1:8181/LEpVqqD7E_Y=/ws',
              apiParameterVmServiceConnected: 'bad_arg',
            },
          );
          expect(response.statusCode, HttpStatus.badRequest);
          expect(
            await response.readAsString(),
            contains('Cannot parse $apiParameterVmServiceConnected parameter'),
          );
        },
      );
    });

    group('endpoints that require DTD', () {
      TestDtdConnectionInfo? dtd;
      DartToolingDaemon? testDtdConnection;

      setUp(() async {
        dtd = await startDtd();
        expect(dtd!.uri, isNotNull, reason: 'Error starting DTD for test');
        testDtdConnection =
            await DartToolingDaemon.connect(Uri.parse(dtd!.uri!));
      });

      tearDown(() async {
        await testDtdConnection?.close();
        dtd?.dtdProcess?.kill();
        await dtd?.dtdProcess?.exitCode;
        dtd = null;
      });

      group('updateDtdWorkspaceRoots', () {
        Future<void> updateWorkspaceRoots({
          required Uri root,
          required bool connected,
        }) async {
          await server.Handler.updateDtdWorkspaceRoots(
            testDtdConnection!,
            dtdConnectionInfo: (uri: dtd!.uri, secret: dtd!.secret),
            rootFromVmService: root,
            connected: connected,
            api: ServerApi(),
          );
        }

        Future<void> verifyWorkspaceRoots(Set<Uri> roots) async {
          final currentRoots = (await testDtdConnection!.getIDEWorkspaceRoots())
              .ideWorkspaceRoots;
          expect(currentRoots, hasLength(roots.length));
          expect(currentRoots, containsAll(roots));
        }

        test(
          'adds and removes workspace roots',
          () async {
            await verifyWorkspaceRoots({});
            final rootUri1 = Uri.parse('file:///Users/me/package_root_1');
            final rootUri2 = Uri.parse('file:///Users/me/package_root_2');

            await updateWorkspaceRoots(root: rootUri1, connected: true);
            await verifyWorkspaceRoots({rootUri1});

            // Add a second root and verify the roots are unioned.
            await updateWorkspaceRoots(root: rootUri2, connected: true);
            await verifyWorkspaceRoots({rootUri1, rootUri2});

            // Verify duplicates cannot be added.
            await updateWorkspaceRoots(root: rootUri2, connected: true);
            await verifyWorkspaceRoots({rootUri1, rootUri2});

            // Verify roots are removed for disconnect events.
            await updateWorkspaceRoots(root: rootUri2, connected: false);
            await verifyWorkspaceRoots({rootUri1});
            await updateWorkspaceRoots(root: rootUri1, connected: false);
            await verifyWorkspaceRoots({});
          },
          timeout: const Timeout.factor(4),
        );
      });

      group('detectRootPackageForVmService', () {
        TestDartApp? app;
        String? vmServiceUriString;

        setUp(() async {
          app = TestDartApp();
          vmServiceUriString = await app!.start();
          // Await a short delay to give the VM a chance to initialize.
          await delay(duration: const Duration(seconds: 1));
          expect(vmServiceUriString, isNotEmpty);
        });

        tearDown(() async {
          await app?.kill();
          app = null;
          vmServiceUriString = null;
        });

        test('succeeds for a connect event', () async {
          final vmServiceUri = normalizeVmServiceUri(vmServiceUriString!);
          expect(vmServiceUri, isNotNull);
          final response = await server.Handler.detectRootPackageForVmService(
            vmServiceUriAsString: vmServiceUriString!,
            vmServiceUri: vmServiceUri!,
            connected: true,
            api: ServerApi(),
            dtd: testDtdConnection!,
          );
          expect(response.success, true);
          expect(response.message, isNull);
          expect(response.uri, isNotNull);
          expect(response.uri!.toString(), endsWith(app!.directory.path));
        });

        test('succeeds for a disconnect event when cache is empty', () async {
          final response = await server.Handler.detectRootPackageForVmService(
            vmServiceUriAsString: vmServiceUriString!,
            vmServiceUri: Uri.parse('ws://127.0.0.1:63555/fake-uri=/ws'),
            connected: false,
            api: ServerApi(),
            dtd: testDtdConnection!,
          );
          expect(response, (success: true, message: null, uri: null));
        });

        test(
          'succeeds for a disconnect event when cache contains entry for VM service',
          () async {
            final vmServiceUri = normalizeVmServiceUri(vmServiceUriString!);
            expect(vmServiceUri, isNotNull);
            final response = await server.Handler.detectRootPackageForVmService(
              vmServiceUriAsString: vmServiceUriString!,
              vmServiceUri: vmServiceUri!,
              connected: true,
              api: ServerApi(),
              dtd: testDtdConnection!,
            );
            expect(response.success, true);
            expect(response.message, isNull);
            expect(response.uri, isNotNull);
            expect(response.uri!.toString(), endsWith(app!.directory.path));

            final disconnectResponse =
                await server.Handler.detectRootPackageForVmService(
              vmServiceUriAsString: vmServiceUriString!,
              vmServiceUri: vmServiceUri,
              connected: false,
              api: ServerApi(),
              dtd: testDtdConnection!,
            );
            expect(disconnectResponse.success, true);
            expect(disconnectResponse.message, isNull);
            expect(disconnectResponse.uri, isNotNull);
            expect(
              disconnectResponse.uri!.toString(),
              endsWith(app!.directory.path),
            );
          },
        );
      });
    });
  });
}

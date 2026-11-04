// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:devtools_shared/devtools_server.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart' as server;
import 'package:dtd/dtd.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../fakes.dart';
import '../helpers/helpers.dart';

void main() {
  group('General DevTools server API', () {
    group('request validation', () {
      Future<Response> sendServerRequest({
        String method = 'POST',
        String uriHost = 'localhost',
        Map<String, Object>? headers,
        // ignore: avoid-redundant-async, returning FutureOr.
      }) async {
        final request = Request(
          method,
          Uri(scheme: 'http', host: uriHost, path: DtdApi.apiGetDtdUri),
          headers: headers,
        );
        return server.ServerApi.handle(
          request,
          extensionsManager: ExtensionsManager(),
          deeplinkManager: FakeDeeplinkManager(),
        );
      }

      test(
        'rejects unsupported HTTP methods with 405 Method Not Allowed',
        () async {
          for (final method in [
            'GET',
            'get',
            'PUT',
            'DELETE',
            'PATCH',
            'HEAD',
          ]) {
            final response = await sendServerRequest(method: method);
            expect(response.statusCode, HttpStatus.methodNotAllowed);
            expect(
              await response.readAsString(),
              'Method Not Allowed: $method',
            );
          }
        },
      );

      test(
        'handles OPTIONS preflight requests from loopback origins',
        () async {
          for (final method in ['OPTIONS', 'options']) {
            for (final headers in [
              {
                HttpHeaders.hostHeader: '127.0.0.1:9104',
                'origin': 'http://localhost:54321',
                'sec-fetch-site': 'cross-site',
                HttpHeaders.accessControlRequestMethodHeader: 'POST',
                HttpHeaders.accessControlRequestHeadersHeader:
                    devToolsRequestHeader.toLowerCase(),
              },
              {
                HttpHeaders.hostHeader: 'localhost:9104',
                'origin': 'http://localhost:54321',
                'sec-fetch-site': 'same-site',
                HttpHeaders.accessControlRequestMethodHeader: 'POST',
                HttpHeaders.accessControlRequestHeadersHeader:
                    devToolsRequestHeader.toLowerCase(),
              },
            ]) {
              final response = await sendServerRequest(
                method: method,
                headers: headers,
              );
              expect(response.statusCode, HttpStatus.noContent);
              expect(await response.readAsString(), isEmpty);
              expect(
                response.headers[HttpHeaders.accessControlAllowMethodsHeader],
                'POST, OPTIONS',
              );
              expect(
                response.headers[HttpHeaders.accessControlAllowHeadersHeader],
                devToolsRequestHeader,
              );
              expect(
                response.headers.containsKey(
                  HttpHeaders.accessControlAllowOriginHeader,
                ),
                isFalse,
              );
            }
          }
        },
      );

      test('rejects OPTIONS preflight requests with invalid headers', () async {
        final invalidPreflights = [
          {
            HttpHeaders.hostHeader: 'evil.com:9104',
            'origin': 'http://localhost:54321',
          },
          {
            HttpHeaders.hostHeader: '127.0.0.1:9104',
            'origin': 'https://evil.com',
            'sec-fetch-site': 'cross-site',
          },
          {
            HttpHeaders.hostHeader: '127.0.0.1:9104',
            'sec-fetch-site': 'cross-site',
          },
        ];
        for (final headers in invalidPreflights) {
          final response = await sendServerRequest(
            method: 'OPTIONS',
            headers: headers,
          );
          expect(response.statusCode, HttpStatus.forbidden);
          expect(
            response.headers.containsKey(
              HttpHeaders.accessControlAllowMethodsHeader,
            ),
            isFalse,
          );
          expect(
            response.headers.containsKey(
              HttpHeaders.accessControlAllowHeadersHeader,
            ),
            isFalse,
          );
        }
      });

      test('rejects non-loopback Host headers with 403 Forbidden', () async {
        const invalidHosts = [
          'evil.com',
          'evil.com:9100',
          'localhost.evil.com',
          '127.0.0.1.evil.com',
          'localhost@evil.com',
          '8.8.8.8',
          '0.0.0.0',
          '',
        ];
        for (final invalidHost in invalidHosts) {
          final response = await sendServerRequest(
            headers: {HttpHeaders.hostHeader: invalidHost},
          );
          expect(
            response.statusCode,
            HttpStatus.forbidden,
            reason: 'Expected Host "$invalidHost" to be rejected',
          );
          expect(await response.readAsString(), 'Invalid Host header');
        }

        final nonLoopbackUriResponse = await sendServerRequest(
          uriHost: 'evil.com',
        );
        expect(nonLoopbackUriResponse.statusCode, HttpStatus.forbidden);
        expect(
          await nonLoopbackUriResponse.readAsString(),
          'Invalid Host header',
        );
      });

      test('accepts loopback Host headers', () async {
        const validHosts = [
          'localhost',
          'localhost:9100',
          '127.0.0.1',
          '127.0.0.1:9100',
          '127.0.0.2:9100',
          '[::1]',
          '[::1]:9100',
          '::1',
        ];
        for (final validHost in validHosts) {
          final response = await sendServerRequest(
            headers: {HttpHeaders.hostHeader: validHost},
          );
          expect(
            response.statusCode,
            HttpStatus.ok,
            reason: 'Expected Host "$validHost" to be accepted',
          );
        }
      });

      test('rejects non-loopback Origin headers with 403 Forbidden', () async {
        const invalidOrigins = [
          'https://evil.com',
          'http://evil.com:9100',
          'http://localhost.evil.com',
          'http://127.0.0.1.evil.com',
          'http://localhost@evil.com',
          'null',
          '',
        ];
        for (final invalidOrigin in invalidOrigins) {
          final response = await sendServerRequest(
            headers: {'origin': invalidOrigin},
          );
          expect(
            response.statusCode,
            HttpStatus.forbidden,
            reason: 'Expected Origin "$invalidOrigin" to be rejected',
          );
          expect(await response.readAsString(), 'Invalid Origin header');
        }
      });

      test('accepts loopback Origin headers', () async {
        const validOrigins = [
          'http://localhost:9100',
          'https://localhost:9100',
          'http://127.0.0.1:9100',
          'http://127.0.0.2:9100',
          'http://[::1]:9100',
        ];
        for (final validOrigin in validOrigins) {
          final response = await sendServerRequest(
            headers: {'origin': validOrigin},
          );
          expect(
            response.statusCode,
            HttpStatus.ok,
            reason: 'Expected Origin "$validOrigin" to be accepted',
          );
        }
      });

      test(
        'rejects Sec-Fetch-Site: cross-site without loopback Origin',
        () async {
          final response = await sendServerRequest(
            headers: {'sec-fetch-site': 'cross-site'},
          );
          expect(response.statusCode, HttpStatus.forbidden);
          expect(
            await response.readAsString(),
            'Cross-site requests are not allowed',
          );

          final evilOriginResponse = await sendServerRequest(
            headers: {
              'origin': 'https://evil.com',
              'sec-fetch-site': 'cross-site',
            },
          );
          expect(evilOriginResponse.statusCode, HttpStatus.forbidden);

          final invalidValueWithLoopbackOrigin = await sendServerRequest(
            headers: {
              'origin': 'http://localhost:54321',
              'sec-fetch-site': 'unexpected',
            },
          );
          expect(
            invalidValueWithLoopbackOrigin.statusCode,
            HttpStatus.forbidden,
          );

          final crossPortLoopbackResponse = await sendServerRequest(
            headers: {
              HttpHeaders.hostHeader: '127.0.0.1:9104',
              'origin': 'http://localhost:54321',
              'sec-fetch-site': 'cross-site',
            },
          );
          expect(crossPortLoopbackResponse.statusCode, HttpStatus.ok);

          for (final allowed in ['same-origin', 'same-site', 'none']) {
            final okResponse = await sendServerRequest(
              headers: {'sec-fetch-site': allowed},
            );
            expect(
              okResponse.statusCode,
              HttpStatus.ok,
              reason: 'Expected Sec-Fetch-Site "$allowed" to be accepted',
            );
          }
        },
      );
    });

    group(apiNotifyForVmServiceConnection, () {
      Future<Response> sendNotifyRequest({
        required DtdInfo? dtd,
        Map<String, Object?>? queryParameters,
        // ignore: avoid-redundant-async, returning FutureOr.
      }) async {
        final request = Request(
          'post',
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

      test('succeeds when DTD is not available', () async {
        final response = await sendNotifyRequest(
          dtd: null,
          queryParameters: {
            apiParameterValueKey: 'fake_uri',
            apiParameterVmServiceConnected: 'true',
          },
        );
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), isEmpty);
      });

      test('returns badRequest for invalid VM service argument', () async {
        final response = await sendNotifyRequest(
          dtd: DtdInfo(Uri.parse('ws://dtd/uri'), secret: 'fake_secret'),
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
      });
      test(
        'returns badRequest for invalid $apiParameterVmServiceConnected argument',
        () async {
          final response = await sendNotifyRequest(
            dtd: DtdInfo(Uri.parse('ws://dtd/uri'), secret: 'fake_secret'),
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
        expect(dtd!.info, isNotNull, reason: 'Error starting DTD for test');
        testDtdConnection = await DartToolingDaemon.connect(
          dtd!.info!.localUri,
        );
      });

      tearDown(() async {
        await testDtdConnection?.close();
        dtd?.process?.kill();
        await dtd?.process?.exitCode;
        dtd = null;
      });

      group('updateDtdWorkspaceRoots', () {
        Future<void> updateWorkspaceRoots({
          required Uri root,
          required bool connected,
        }) async {
          await server.VmServiceHandler.updateDtdWorkspaceRoots(
            testDtdConnection!,
            dtdConnectionInfo: dtd!.info!,
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

        test('adds and removes workspace roots', () async {
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
        }, timeout: const Timeout.factor(4));
      });

      group('detectRootPackageForVmService', () {
        TestDartApp? app;
        String? vmServiceUriString;

        setUp(() async {
          app = TestDartApp();
          vmServiceUriString = await app!.start();
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
          late server.DetectRootPackageResponse response;
          await runWithRetry(
            callback: () async {
              response =
                  await server.VmServiceHandler.detectRootPackageForVmService(
                    vmServiceUriAsString: vmServiceUriString!,
                    vmServiceUri: vmServiceUri!,
                    connected: true,
                    dtd: testDtdConnection!,
                  );
              if (!response.success) throw Exception('VM not ready');
            },
            maxRetries: 20,
            retryDelay: const Duration(milliseconds: 500),
          );
          expect(response.success, true);
          expect(response.message, isNull);
          expect(response.uri, isNotNull);
          expect(response.uri!.toFilePath(), endsWith(app!.directory.path));
        });

        test('succeeds for a disconnect event when cache is empty', () async {
          final response =
              await server.VmServiceHandler.detectRootPackageForVmService(
                vmServiceUriAsString: vmServiceUriString!,
                vmServiceUri: Uri.parse('ws://127.0.0.1:63555/fake-uri=/ws'),
                connected: false,
                dtd: testDtdConnection!,
              );
          expect(response, (success: true, message: null, uri: null));
        });

        test(
          'succeeds for a disconnect event when cache contains entry for VM service',
          () async {
            final vmServiceUri = normalizeVmServiceUri(vmServiceUriString!);
            expect(vmServiceUri, isNotNull);
            late server.DetectRootPackageResponse response;
            await runWithRetry(
              callback: () async {
                response =
                    await server.VmServiceHandler.detectRootPackageForVmService(
                      vmServiceUriAsString: vmServiceUriString!,
                      vmServiceUri: vmServiceUri!,
                      connected: true,
                      dtd: testDtdConnection!,
                    );
                if (!response.success) throw Exception('VM not ready');
              },
              maxRetries: 20,
              retryDelay: const Duration(milliseconds: 500),
            );
            expect(response.success, true);
            expect(response.message, isNull);
            expect(response.uri, isNotNull);
            expect(response.uri!.toFilePath(), endsWith(app!.directory.path));

            final disconnectResponse =
                await server.VmServiceHandler.detectRootPackageForVmService(
                  vmServiceUriAsString: vmServiceUriString!,
                  vmServiceUri: vmServiceUri!,
                  connected: false,
                  dtd: testDtdConnection!,
                );
            expect(disconnectResponse.success, true);
            expect(disconnectResponse.message, isNull);
            expect(disconnectResponse.uri, isNotNull);
            expect(
              disconnectResponse.uri!.toFilePath(),
              endsWith(app!.directory.path),
            );
          },
        );
      });
    });
  });
}

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:unified_analytics/unified_analytics.dart';

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
        analytics: const NoOpAnalytics(),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(
        await response.readAsString(),
        jsonEncode({DtdApi.uriPropertyName: dtdUri}),
      );
    });

    test('handle ${DtdApi.apiSetDtdWorkspaceRoots} succeeds', () async {
      final dtd = await _startDtd();
      final request = Request(
        'get',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: DtdApi.apiSetDtdWorkspaceRoots,
          queryParameters: {
            DtdApi.workspaceRootsPropertyName:
                'file:///Users/me/package_root_1,file:///Users/me/package_root_2',
          },
        ),
      );
      final response = await ServerApi.handle(
        request,
        extensionsManager: ExtensionsManager(buildDir: '/'),
        deeplinkManager: FakeDeeplinkManager(),
        dtd: (uri: dtd.uri, secret: dtd.secret),
        analytics: const NoOpAnalytics(),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), isEmpty);

      dtd.dtdProcess?.kill();
      await dtd.dtdProcess?.exitCode;
    });

    test(
      'handle ${DtdApi.apiSetDtdWorkspaceRoots} returns error when DTD is not available',
      () async {
        final request = Request(
          'get',
          Uri(
            scheme: 'https',
            host: 'localhost',
            path: DtdApi.apiSetDtdWorkspaceRoots,
            queryParameters: {
              DtdApi.workspaceRootsPropertyName:
                  'file:///Users/me/package_root_1,file:///Users/me/package_root_2',
            },
          ),
        );
        final response = await ServerApi.handle(
          request,
          extensionsManager: ExtensionsManager(buildDir: '/'),
          deeplinkManager: FakeDeeplinkManager(),
          dtd: (uri: null, secret: null),
          analytics: const NoOpAnalytics(),
        );
        expect(response.statusCode, HttpStatus.internalServerError);
        expect(
          await response.readAsString(),
          contains('Cannot set workspace roots because DTD is not available.'),
        );
      },
    );

    test(
      'handle ${DtdApi.apiSetDtdWorkspaceRoots} returns forbidden response '
      'when DevTools server is not the trusted client',
      () async {
        const dtdUri = 'ws://dtd:uri';
        final request = Request(
          'get',
          Uri(
            scheme: 'https',
            host: 'localhost',
            path: DtdApi.apiSetDtdWorkspaceRoots,
            queryParameters: {
              DtdApi.workspaceRootsPropertyName:
                  'file:///Users/me/package_root_1,file:///Users/me/package_root_2',
            },
          ),
        );
        final response = await ServerApi.handle(
          request,
          extensionsManager: ExtensionsManager(buildDir: '/'),
          deeplinkManager: FakeDeeplinkManager(),
          dtd: (uri: dtdUri, secret: null),
          analytics: const NoOpAnalytics(),
        );
        expect(response.statusCode, HttpStatus.forbidden);
        expect(
          await response.readAsString(),
          contains(
            'Cannot set workspace roots because DevTools server is not the trusted client for DTD.',
          ),
        );
      },
    );

    test('can encode and decode workspace roots', () {
      var roots = [
        'file:///Users/me/package_root_1',
        'file:///Users/me/package_root_2',
      ];
      var encoded =
          'file:///Users/me/package_root_1,file:///Users/me/package_root_2';
      expect(DtdApi.encodeWorkspaceRoots(roots), encoded);
      expect(DtdApi.decodeWorkspaceRoots(encoded), roots);

      roots = [];
      encoded = DtdApi.workspaceRootsValueEmpty;
      expect(DtdApi.encodeWorkspaceRoots(roots), encoded);
      expect(DtdApi.decodeWorkspaceRoots(encoded), roots);
    });
  });
}

/// Helper method to start DTD for the purpose of testing.
Future<({String? uri, String? secret, Process? dtdProcess})> _startDtd() async {
  final completer =
      Completer<({String? uri, String? secret, Process? dtdProcess})>();
  Process? dtdProcess;
  try {
    dtdProcess = await Process.start(
      Platform.resolvedExecutable,
      ['tooling-daemon', '--machine'],
    );
    dtdProcess.stdout.listen((List<int> data) {
      try {
        final decoded = utf8.decode(data);
        final json = jsonDecode(decoded) as Map<String, Object?>;
        if (json
            case {
              'tooling_daemon_details': {
                'uri': final String uri,
                'trusted_client_secret': final String secret,
              }
            }) {
          completer.complete(
            (uri: uri, secret: secret, dtdProcess: dtdProcess),
          );
        } else {
          completer.complete((uri: null, secret: null, dtdProcess: dtdProcess));
        }
      } catch (e) {
        completer.complete((uri: null, secret: null, dtdProcess: dtdProcess));
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => (uri: null, secret: null, dtdProcess: dtdProcess),
    );
  } catch (e) {
    return (uri: null, secret: null, dtdProcess: dtdProcess);
  }
}

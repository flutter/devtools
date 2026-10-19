// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectedApp', () {
    test('isDartWebApp is true when dart:html is available', () async {
      final serviceManager = _FakeServiceManager(
        availableLibraries: ['dart:html'],
      );
      final app = ConnectedApp(serviceManager);
      expect(await app.isDartWebApp, isTrue);
      expect(app.isDartWebAppNow, isTrue);
    });

    test('isDartWebApp is true when dart:js_interop is available', () async {
      final serviceManager = _FakeServiceManager(
        availableLibraries: ['dart:js_interop'],
      );
      final app = ConnectedApp(serviceManager);
      expect(await app.isDartWebApp, isTrue);
      expect(app.isDartWebAppNow, isTrue);
    });

    test(
      'isDartWebApp is true when dart:js_interop_unsafe is available',
      () async {
        final serviceManager = _FakeServiceManager(
          availableLibraries: ['dart:js_interop_unsafe'],
        );
        final app = ConnectedApp(serviceManager);
        expect(await app.isDartWebApp, isTrue);
        expect(app.isDartWebAppNow, isTrue);
      },
    );

    test('isDartWebApp is false when no web libraries are available', () async {
      final serviceManager = _FakeServiceManager(
        availableLibraries: [
          'dart:io',
          'package:flutter/src/widgets/binding.dart',
        ],
      );
      final app = ConnectedApp(serviceManager);
      expect(await app.isDartWebApp, isFalse);
      expect(app.isDartWebAppNow, isFalse);
    });

    test('isDartWebApp short-circuits on first matching library', () async {
      final queriedLibraries = <String>[];
      final serviceManager = _FakeServiceManager(
        availableLibraries: ['dart:html', 'dart:js_interop'],
        onLibraryUriAvailable: queriedLibraries.add,
      );
      final app = ConnectedApp(serviceManager);

      expect(await app.isDartWebApp, isTrue);
      expect(queriedLibraries, equals(['dart:html']));
    });

    test('isDartWebApp caches results', () async {
      var callCount = 0;
      final serviceManager = _FakeServiceManager(
        availableLibraries: ['dart:js_interop'],
        onLibraryUriAvailable: (_) => callCount++,
      );
      final app = ConnectedApp(serviceManager);

      expect(await app.isDartWebApp, isTrue);
      final callsAfterFirst = callCount;
      expect(callsAfterFirst, greaterThan(0));

      expect(await app.isDartWebApp, isTrue);
      expect(callCount, equals(callsAfterFirst));
    });

    test('isDartWebAppNow asserts when not initialized', () {
      final serviceManager = _FakeServiceManager();
      final app = ConnectedApp(serviceManager);
      expect(() => app.isDartWebAppNow, throwsAssertionError);
    });

    test(
      'isFlutterWebAppNow is true and isFlutterNativeAppNow is false for modern Flutter web apps',
      () async {
        final serviceManager = _FakeServiceManager(
          availableLibraries: [flutterLibraryUri, 'dart:js_interop'],
        );
        final app = ConnectedApp(serviceManager);
        expect(await app.isFlutterApp, isTrue);
        expect(await app.isDartWebApp, isTrue);
        expect(app.isFlutterWebAppNow, isTrue);
        expect(app.isFlutterNativeAppNow, isFalse);
      },
    );
  });

  group('OfflineConnectedApp', () {
    test(
      'isDartWebApp returns the recorded value without a service manager',
      () async {
        expect(
          await OfflineConnectedApp(isDartWebAppNow: true).isDartWebApp,
          isTrue,
        );
        expect(
          await OfflineConnectedApp(isDartWebAppNow: false).isDartWebApp,
          isFalse,
        );
        expect(await OfflineConnectedApp().isDartWebApp, isFalse);
      },
    );
  });

  group('constants', () {
    test('dartWebLibraryUris contains all web library URIs', () {
      expect(
        dartWebLibraryUris,
        containsAll([
          dartHtmlLibraryUri,
          dartJsInteropLibraryUri,
          dartJsInteropUnsafeLibraryUri,
        ]),
      );
    });
  });
}

class _FakeServiceManager extends Fake implements ServiceManager {
  _FakeServiceManager({
    this.availableLibraries = const [],
    this.onLibraryUriAvailable,
  });

  final List<String> availableLibraries;
  final void Function(String uri)? onLibraryUriAvailable;

  @override
  bool libraryUriAvailableNow(String? uri) {
    if (uri == null) return false;
    onLibraryUriAvailable?.call(uri);
    return availableLibraries.any((u) => u.startsWith(uri));
  }

  @override
  Future<bool> libraryUriAvailable(String uri) async {
    return libraryUriAvailableNow(uri);
  }
}

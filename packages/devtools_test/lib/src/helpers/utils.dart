// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

const skipForCustomerTestsTag = 'skip-for-flutter-customer-tests';

const shortPumpDuration = Duration(seconds: 1);
const safePumpDuration = Duration(seconds: 3);
const longPumpDuration = Duration(seconds: 6);
const veryLongPumpDuration = Duration(seconds: 9);

final screenIds = <String>[
  AppSizeScreen.id,
  DebuggerScreen.id,
  DeepLinksScreen.id,
  InspectorScreen.id,
  LoggingScreen.id,
  MemoryScreen.id,
  NetworkScreen.id,
  PerformanceScreen.id,
  ProfilerScreen.id,
  ProviderScreen.id,
  VMDeveloperToolsScreen.id,
];

/// Scoping method which registers `listener` as a listener for `listenable`,
/// invokes `callback`, and then removes the `listener`.
///
/// Tests that `listener` has actually been invoked.
Future<void> addListenerScope({
  required Listenable listenable,
  required void Function() listener,
  required Future<void> Function() callback,
}) async {
  bool listenerCalled = false;
  void listenerWrapped() {
    listenerCalled = true;
    listener();
  }

  listenable.addListener(listenerWrapped);
  await callback();
  expect(listenerCalled, true);
  listenable.removeListener(listenerWrapped);
}

/// Returns a future that completes when a listenable has a value that satisfies
/// [condition].
Future<T> whenMatches<T>(
  ValueListenable<T> listenable,
  bool Function(T) condition,
) {
  final completer = Completer<T>();
  void listener() {
    if (condition(listenable.value)) {
      completer.complete(listenable.value);
      listenable.removeListener(listener);
    }
  }

  listenable.addListener(listener);
  listener();
  return completer.future;
}

/// Workaround to initialize the live widget binding with assets.
///
/// The [LiveTestWidgetsFlutterBinding] is useful for unit tests that need to
/// perform true async operations such as communicating with the VM Service.
/// Unfortunately the default implementation doesn't work with the patterns we
/// use to load assets in the devtools application.
/// TODO(jacobr): consider writing proper integration tests instead rather than
/// using this code path.
void initializeLiveTestWidgetsFlutterBindingWithAssets() {
  TestWidgetsFlutterBinding.ensureInitialized({'FLUTTER_TEST': 'false'});
  _mockFlutterAssets();
}

// Copied from _binding_io.dart from package:flutter_test,
// This code is typically used to load assets in regular unittests but not
// unittests run with the LiveTestWidgetsFlutterBinding. Assets should be able
// to load normally when running unittests using the
// LiveTestWidgetsFlutterBinding but that is not the case at least for the
// devtools app so we use this workaround.
void _mockFlutterAssets() {
  if (!Platform.environment.containsKey('UNIT_TEST_ASSETS')) {
    return;
  }
  final assetFolderPath = Platform.environment['UNIT_TEST_ASSETS'];
  assert(Platform.environment['APP_NAME'] != null);
  final prefix = 'packages/${Platform.environment['APP_NAME']}/';

  /// Navigation related actions (pop, push, replace) broadcasts these actions via
  /// platform messages.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.navigation, null);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      assert(message != null);
      String key = utf8.decode(message!.buffer.asUint8List());
      File asset = File(path.join(assetFolderPath!, key));

      if (!asset.existsSync()) {
        // For tests in package, it will load assets with its own package prefix.
        // In this case, we do a best-effort look up.
        if (!key.startsWith(prefix)) {
          return null;
        }

        key = key.replaceFirst(prefix, '');
        asset = File(path.join(assetFolderPath, key));
        if (!asset.existsSync()) {
          return null;
        }
      }

      final encoded = Uint8List.fromList(asset.readAsBytesSync());
      return Future<ByteData>.value(encoded.buffer.asByteData());
    },
  );
}

// TODO(https://github.com/flutter/devtools/issues/6215): remove this helper.
/// Load fonts used by the devtool for golden-tests to use them
Future<void> loadFonts() async {
  // source: https://medium.com/swlh/test-your-flutter-widgets-using-golden-files-b533ac0de469

  //https://github.com/flutter/flutter/issues/20907
  if (Directory.current.path.endsWith('/test')) {
    Directory.current = Directory.current.parent;
  }

  const fonts = {
    'Roboto': [
      'fonts/Roboto/Roboto-Thin.ttf',
      'fonts/Roboto/Roboto-Light.ttf',
      'fonts/Roboto/Roboto-Regular.ttf',
      'fonts/Roboto/Roboto-Medium.ttf',
      'fonts/Roboto/Roboto-Bold.ttf',
      'fonts/Roboto/Roboto-Black.ttf',
    ],
    'RobotoMono': [
      'fonts/Roboto_Mono/RobotoMono-Thin.ttf',
      'fonts/Roboto_Mono/RobotoMono-Light.ttf',
      'fonts/Roboto_Mono/RobotoMono-Regular.ttf',
      'fonts/Roboto_Mono/RobotoMono-Medium.ttf',
      'fonts/Roboto_Mono/RobotoMono-Bold.ttf',
    ],
    'Octicons': ['fonts/Octicons.ttf'],
  };

  final loadFontsFuture = fonts.entries.map((entry) async {
    final loader = FontLoader(entry.key);

    for (final path in entry.value) {
      final fontData = File(path).readAsBytes().then((bytes) {
        return ByteData.view(Uint8List.fromList(bytes).buffer);
      });

      loader.addFont(fontData);
    }

    await loader.load();
  });

  await Future.wait(loadFontsFuture);
}

void verifyIsSearchMatch(
  List<SearchableDataMixin> data,
  List<SearchableDataMixin> matches,
) {
  for (final request in data) {
    if (matches.contains(request)) {
      expect(request.isSearchMatch, isTrue);
    } else {
      expect(request.isSearchMatch, isFalse);
    }
  }
}

void verifyIsSearchMatchForTreeData<T extends TreeDataSearchStateMixin<T>>(
  List<T> data,
  List<T> matches,
) {
  for (final node in data) {
    breadthFirstTraversal<T>(
      node,
      action: (T e) {
        if (matches.contains(e)) {
          expect(e.isSearchMatch, isTrue);
        } else {
          expect(e.isSearchMatch, isFalse);
        }
      },
    );
  }
}

void logStatus(String log) {
  // ignore: avoid_print, intentional print for test output
  print('TEST STATUS: $log');
}

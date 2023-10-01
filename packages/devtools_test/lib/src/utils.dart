// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vm_snapshot_analysis/treemap.dart';

final screenIds = <String>[
  AppSizeScreen.id,
  DebuggerScreen.id,
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
  required Function listener,
  required Function callback,
}) async {
  bool listenerCalled = false;
  final listenerWrapped = () {
    listenerCalled = true;
    listener();
  };

  listenable.addListener(listenerWrapped);
  await callback();
  expect(listenerCalled, true);
  listenable.removeListener(listenerWrapped);
}

/// Returns a future that completes when a listenable has a value that satisfies
/// [condition].
Future<T> whenMatches<T>(ValueListenable<T> listenable, bool condition(T)) {
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

Future<TreemapNode> loadSnapshotJsonAsTree(String snapshotJson) async {
  final treemapTestData = jsonDecode(snapshotJson);

  if (treemapTestData is Map<String, dynamic> &&
      treemapTestData['type'] == 'apk') {
    return generateTree(treemapTestData);
  } else {
    final processedTestData = treemapFromJson(treemapTestData);
    processedTestData['n'] = 'Root';
    return generateTree(processedTestData);
  }
}

/// Builds a tree with [TreemapNode] from [treeJson] which represents
/// the hierarchical structure of the tree.
TreemapNode generateTree(Map<String, dynamic> treeJson) {
  var treemapNodeName = treeJson['n'];
  if (treemapNodeName == '') treemapNodeName = 'Unnamed';
  final rawChildren = treeJson['children'];
  final treemapNodeChildren = <TreemapNode>[];

  int treemapNodeSize = 0;
  if (rawChildren != null) {
    // If not a leaf node, build all children then take the sum of the
    // children's sizes as its own size.
    for (var child in rawChildren) {
      final childTreemapNode = generateTree(child);
      treemapNodeChildren.add(childTreemapNode);
      treemapNodeSize += childTreemapNode.byteSize;
    }
    treemapNodeSize = treemapNodeSize;
  } else {
    // If a leaf node, just take its own size.
    // Defaults to 0 if a leaf node has a size of null.
    treemapNodeSize = treeJson['value'] ?? 0;
  }

  return TreemapNode(name: treemapNodeName, byteSize: treemapNodeSize)
    ..addAllChildren(treemapNodeChildren);
}

Finder findSubstring(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is Text) {
      if (widget.data != null) return widget.data!.contains(text);
      return widget.textSpan!.toPlainText().contains(text);
    } else if (widget is RichText) {
      return widget.text.toPlainText().contains(text);
    } else if (widget is SelectableText) {
      if (widget.data != null) return widget.data!.contains(text);
    }
    return false;
  });
}

extension RichTextChecking on CommonFinders {
  Finder richText(String text) {
    return find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    );
  }

  Finder richTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
    );
  }
}

extension SelectableTextChecking on CommonFinders {
  Finder selectableText(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText &&
          (widget.data == text || widget.textSpan?.toPlainText() == text),
    );
  }

  Finder selectableTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText &&
          ((widget.data?.contains(text) ?? false) ||
              (widget.textSpan?.toPlainText().contains(text) ?? false)),
    );
  }
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
  final String? assetFolderPath = Platform.environment['UNIT_TEST_ASSETS'];
  assert(Platform.environment['APP_NAME'] != null);
  final String prefix = 'packages/${Platform.environment['APP_NAME']}/';

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

      final Uint8List encoded = Uint8List.fromList(asset.readAsBytesSync());
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
    // 'Codicon': ['packages/codicon/font/codicon.ttf']
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

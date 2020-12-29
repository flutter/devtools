// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:devtools_app/src/charts/treemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_snapshot_analysis/treemap.dart';
import 'package:path/path.dart' as path;

import 'network_test_data.dart';

/// Scoping method which registers `listener` as a listener for `listenable`,
/// invokes `callback`, and then removes the `listener`.
///
/// Tests that `listener` has actually been invoked.
Future<void> addListenerScope({
  @required dynamic listenable,
  @required Function listener,
  @required Function callback,
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

/// Creates an instance of [Timeline] which contains recorded HTTP events.
Future<Timeline> loadNetworkProfileTimeline() async {
  // TODO(bkonyi): pull this JSON data into a .dart file.
  const testDataPath =
      '../devtools_testing/lib/support/http_request_timeline_test_data.json';
  final httpTestData = jsonDecode(
    await File(testDataPath).readAsString(),
  );
  return Timeline.parse(httpTestData);
}

SocketProfile loadSocketProfile() {
  return SocketProfile(sockets: [
    SocketStatistic.parse(testSocket1Json),
    SocketStatistic.parse(testSocket2Json),
  ]);
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
    for (dynamic child in rawChildren) {
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

Future delay() {
  return Future.delayed(const Duration(milliseconds: 500));
}

Future shortDelay() {
  return Future.delayed(const Duration(milliseconds: 100));
}

Finder findSubstring(Widget widget, String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is Text) {
      if (widget.data != null) return widget.data.contains(text);
      return widget.textSpan.toPlainText().contains(text);
    } else if (widget is SelectableText) {
      if (widget.data != null) return widget.data.contains(text);
    }

    return false;
  });
}

extension RichTextChecking on CommonFinders {
  Finder richText(String text) {
    return find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == text);
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
  final String assetFolderPath = Platform.environment['UNIT_TEST_ASSETS'];
  assert(Platform.environment['APP_NAME'] != null);
  final String prefix = 'packages/${Platform.environment['APP_NAME']}/';

  /// Navigation related actions (pop, push, replace) broadcasts these actions via
  /// platform messages.
  SystemChannels.navigation
      .setMockMethodCallHandler((MethodCall methodCall) async {});

  ServicesBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData message) async {
    assert(message != null);
    String key = utf8.decode(message.buffer.asUint8List());
    File asset = File(path.join(assetFolderPath, key));

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
  });
}

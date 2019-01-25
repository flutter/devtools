// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:io';

import 'package:test/test.dart';

import 'package:devtools/inspector/diagnostics_node.dart';
import 'package:devtools/inspector/flutter_widget.dart';
import 'package:devtools/inspector/inspector_service.dart';

import 'matchers/fake_flutter_matchers.dart';
import 'matchers/matchers.dart';
import 'support/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'support/flutter_test_environment.dart';

/// Switch this flag to false to debug issues with non-atomic test behavior.
bool reuseTestEnvironment = true;

void main() async {
  Catalog.setCatalog(
      Catalog.decode(await File('web/widgets.json').readAsString()));
  InspectorService inspectorService;

  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  env.afterNewSetup = () async {
    await ensureInspectorServiceDependencies();
    inspectorService = await InspectorService.create(env.service);
    if (env.runConfig.trackWidgetCreation) {
      await inspectorService.inferPubRootDirectoryIfNeeded();
    }
  };

  env.beforeTearDown = () {
    inspectorService.dispose();
    inspectorService = null;
  };

  try {
    group('inspector service tests', () {
      tearDownAll(() async {
        await env.tearDownEnvironment(force: true);
      });

      test('track widget creation on', () async {
        await env.setupEnvironment();
        expect(await inspectorService.isWidgetCreationTracked(), isTrue);
        await env.tearDownEnvironment();
      });

      test('useDaemonApi', () async {
        await env.setupEnvironment();
        expect(inspectorService.useDaemonApi, isTrue);
        // TODO(jacobr): add test where we trigger a breakpoint and verify that
        // the daemon api is now false.

        await env.tearDownEnvironment();
      });

      test('hasServiceMethod', () async {
        await env.setupEnvironment();
        expect(inspectorService.hasServiceMethod('someDummyName'), isFalse);
        expect(inspectorService.hasServiceMethod('getRootWidgetSummaryTree'),
            isTrue);

        await env.tearDownEnvironment();
      });

      test('createObjectGroup', () async {
        await env.setupEnvironment();

        final g1 = inspectorService.createObjectGroup('g1');
        final g2 = inspectorService.createObjectGroup('g2');
        expect(g1.groupName != g2.groupName, isTrue);
        expect(g1.disposed, isFalse);
        expect(g2.disposed, isFalse);
        final g1Disposed = g1.dispose();
        expect(g1.disposed, isTrue);
        expect(g2.disposed, isFalse);
        final g2Disposed = g2.dispose();
        expect(g2.disposed, isTrue);
        await g1Disposed;
        await g2Disposed;

        await env.tearDownEnvironment();
      });

      test('infer pub root directories', () async {
        await env.setupEnvironment();
        final group = inspectorService.createObjectGroup('test-group');
        // These tests are moot if widget creation is not tracked.
        expect(await inspectorService.isWidgetCreationTracked(), isTrue);
        await inspectorService.setPubRootDirectories([]);
        final String rootDirectory =
            await inspectorService.inferPubRootDirectoryIfNeeded();
        expect(rootDirectory, endsWith('/test/fixtures/flutter_app/lib'));
        await group.dispose();

        await env.tearDownEnvironment();
      });

      test('widget tree', () async {
        await env.setupEnvironment();
        final group = inspectorService.createObjectGroup('test-group');
        final RemoteDiagnosticsNode root =
            await group.getRoot(FlutterTreeType.widget);
        // Tree only contains widgets from local app.
        expect(
          treeToDebugString(root),
          equalsIgnoringHashCodes(
            '[root]\n'
                ' └─MyApp\n'
                '   └─MaterialApp\n'
                '     └─Scaffold\n'
                '       ├─Center\n'
                '       │ └─Text\n'
                '       └─AppBar\n'
                '         └─Text\n',
          ),
        );
        RemoteDiagnosticsNode nodeInSummaryTree =
            findNodeMatching(root, 'MaterialApp');
        expect(nodeInSummaryTree, isNotNull);
        expect(
          treeToDebugString(nodeInSummaryTree),
          equalsIgnoringHashCodes(
            'MaterialApp\n'
                ' └─Scaffold\n'
                '   ├─Center\n'
                '   │ └─Text\n'
                '   └─AppBar\n'
                '     └─Text\n',
          ),
        );
        RemoteDiagnosticsNode nodeInDetailsTree =
            await group.getDetailsSubtree(nodeInSummaryTree);
        // When flutter rolls, this string may sometimes change due to
        // implementation details.
        expect(
          treeToDebugStringTruncated(nodeInDetailsTree, 30),
          equalsGoldenIgnoringHashCodes('inspector_service_details_tree.txt'),
        );

        nodeInSummaryTree = findNodeMatching(root, 'Text');
        expect(nodeInSummaryTree, isNotNull);
        expect(
          treeToDebugString(nodeInSummaryTree),
          equalsIgnoringHashCodes(
            'Text\n',
          ),
        );

        nodeInDetailsTree = await group.getDetailsSubtree(nodeInSummaryTree);
        expect(
          treeToDebugString(nodeInDetailsTree),
          equalsIgnoringHashCodes(
            'Text\n'
                ' │ data: "Hello, World!"\n'
                ' │ textAlign: null\n'
                ' │ textDirection: null\n'
                ' │ locale: null\n'
                ' │ softWrap: null\n'
                ' │ overflow: null\n'
                ' │ textScaleFactor: null\n'
                ' │ maxLines: null\n'
                ' │\n'
                ' └─RichText\n'
                '     softWrap: wrapping at box width\n'
                '     maxLines: unlimited\n'
                '     text: "Hello, World!"\n'
                '     renderObject: RenderParagraph#00000 relayoutBoundary=up2\n',
          ),
        );
        expect(nodeInDetailsTree.valueRef, equals(nodeInSummaryTree.valueRef));

        await group.setSelectionInspector(nodeInDetailsTree.valueRef, true);
        var selection =
            await group.getSelection(null, FlutterTreeType.widget, false);
        expect(selection, isNotNull);
        expect(selection.valueRef, equals(nodeInDetailsTree.valueRef));
        expect(
          treeToDebugString(selection),
          equalsIgnoringHashCodes(
            'Text\n'
                ' └─RichText\n',
          ),
        );

        // Get selection in the render tree.
        selection =
            await group.getSelection(null, FlutterTreeType.renderObject, false);
        expect(
          treeToDebugString(selection),
          equalsIgnoringHashCodes(
            'RenderParagraph#00000 relayoutBoundary=up2\n'
                ' └─text: TextSpan\n',
          ),
        );

        await group.dispose();

        await env.tearDownEnvironment();
      });

      test('render tree', () async {
        await env.setupEnvironment(
          config: const FlutterRunConfiguration(
            withDebugger: true,
            trackWidgetCreation: false,
          ),
        );

        final group = inspectorService.createObjectGroup('test-group');
        final RemoteDiagnosticsNode root =
            await group.getRoot(FlutterTreeType.renderObject);
        // Tree only contains widgets from local app.
        expect(
          treeToDebugString(root),
          equalsIgnoringHashCodes(
            'RenderView#00000\n'
                ' └─child: RenderSemanticsAnnotations#00000\n',
          ),
        );
        final child = findNodeMatching(root, 'RenderSemanticsAnnotations');
        expect(child, isNotNull);
        final childDetailsSubtree = await group.getDetailsSubtree(child);
        expect(
          treeToDebugString(childDetailsSubtree),
          equalsIgnoringHashCodes(
            'child: RenderSemanticsAnnotations#00000\n'
                ' │ parentData: <none>\n'
                ' │ constraints: BoxConstraints(w=800.0, h=600.0)\n'
                ' │ size: Size(800.0, 600.0)\n'
                ' │\n'
                ' └─child: RenderCustomPaint#00000\n'
                '   │ parentData: <none> (can use size)\n'
                '   │ constraints: BoxConstraints(w=800.0, h=600.0)\n'
                '   │ size: Size(800.0, 600.0)\n'
                '   │\n'
                '   └─child: RenderPointerListener#00000\n'
                '       parentData: <none> (can use size)\n'
                '       constraints: BoxConstraints(w=800.0, h=600.0)\n'
                '       size: Size(800.0, 600.0)\n'
                '       behavior: deferToChild\n'
                '       listeners: down, up, cancel\n',
          ),
        );

        await group.setSelectionInspector(child.valueRef, true);
        final selection =
            await group.getSelection(null, FlutterTreeType.renderObject, false);
        expect(selection, isNotNull);
        expect(selection.valueRef, equals(child.valueRef));
        expect(
          treeToDebugString(selection),
          equalsIgnoringHashCodes(
            'RenderSemanticsAnnotations#00000\n'
                ' └─child: RenderCustomPaint#00000\n',
          ),
        );

        await env.tearDownEnvironment();
      });

      // Run this test last as it will take a long time due to setting up the test
      // environment from scratch.
      test('track widget creation off', () async {
        await env.setupEnvironment(
          config: const FlutterRunConfiguration(
            withDebugger: true,
            trackWidgetCreation: false,
          ),
        );

        expect(await inspectorService.isWidgetCreationTracked(), isFalse);

        await env.tearDownEnvironment();
      });

      // TODO(jacobr): add tests verifying that we can stop the running device
      // without the InspectorService spewing a bunch of errors.
    }, tags: 'useFlutterSdk');
  } catch (e, s) {
    print(s);
  }
}

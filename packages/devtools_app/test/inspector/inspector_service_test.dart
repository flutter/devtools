// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

@TestOn('vm')
import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import '../test_infra/flutter_test_environment.dart';
import '../test_infra/matchers/matchers.dart';

void main() {
  initializeLiveTestWidgetsFlutterBindingWithAssets();

  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  InspectorService? inspectorService;

  env.afterEverySetup = () async {
    assert(serviceConnection.serviceManager.connectedAppInitialized);
    setGlobal(IdeTheme, IdeTheme());

    inspectorService = InspectorService();
  };

  env.beforeEveryTearDown = () async {
    inspectorService?.onIsolateStopped();
    inspectorService?.dispose();
    inspectorService = null;
  };

  try {
    group('inspector service tests', () {
      tearDown(env.tearDownEnvironment);
      tearDownAll(() => unawaited(env.tearDownEnvironment(force: true)));

      test('track widget creation on', () async {
        await env.setupEnvironment();
        expect(await inspectorService!.isWidgetCreationTracked(), isTrue);
      });

      test('useDaemonApi', () async {
        await env.setupEnvironment();
        expect(inspectorService!.useDaemonApi, isTrue);
        // TODO(jacobr): add test where we trigger a breakpoint and verify that
        // the daemon api is now false.
      });

      test('createObjectGroup', () async {
        await env.setupEnvironment();
        final inspectorServiceLocal = inspectorService!;

        final g1 = inspectorServiceLocal.createObjectGroup('g1');
        final g2 = inspectorServiceLocal.createObjectGroup('g2');
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
      });

      group('pub root directories', () {
        tearDownAll(() async {
          await env.tearDownEnvironment(force: true);
        });

        test('can be added and removed', () async {
          await env.setupEnvironment();
          final inspectorServiceLocal = inspectorService!;
          const testPubRootDirectory = '/alpha/bravo/charlie';

          // Empty the pubroot directories.
          final initialPubRootDirectories =
              await inspectorServiceLocal.getPubRootDirectories();
          await inspectorServiceLocal
              .removePubRootDirectories(initialPubRootDirectories!);
          expect(
            await inspectorServiceLocal.getPubRootDirectories(),
            equals([]),
          );

          // Can add a new pub root directory.
          await inspectorServiceLocal
              .addPubRootDirectories([testPubRootDirectory]);
          expect(
            await inspectorServiceLocal.getPubRootDirectories(),
            equals([
              testPubRootDirectory,
            ]),
          );

          // Can remove the new pub root directory.
          await inspectorServiceLocal
              .removePubRootDirectories([testPubRootDirectory]);
          expect(
            await inspectorServiceLocal.getPubRootDirectories(),
            equals([]),
          );
        });

        test(
          'local classes',
          () async {
            await env.setupEnvironment();
            final inspectorServiceLocal = inspectorService!;
            final group = inspectorServiceLocal.createObjectGroup('test-group');
            // These tests are moot if widget creation is not tracked.
            expect(
              await inspectorServiceLocal.isWidgetCreationTracked(),
              isTrue,
            );
            final rootLibrary =
                await serviceConnection.rootLibraryForMainIsolate();
            await inspectorServiceLocal.addPubRootDirectories([rootLibrary!]);
            final List<String> rootDirectories =
                await inspectorServiceLocal.getPubRootDirectories() ?? [];
            expect(rootDirectories.length, 1);
            expect(rootDirectories.first, endsWith('/fixtures/flutter_app'));
            final originalRootDirectories = rootDirectories.toList();
            try {
              expect(
                (inspectorServiceLocal.localClasses.keys.toList()..sort()),
                equals(
                  [
                    'AnotherClass',
                    'ExportedClass',
                    'FooClass',
                    'MyApp',
                    'MyOtherWidget',
                    'NotAWidget',
                    '_PrivateClass',
                    '_PrivateExportedClass',
                  ],
                ),
              );

              await inspectorServiceLocal
                  .addPubRootDirectories(['${rootDirectories.first}/lib/src']);
              // Adding src does not change the directory as local classes are
              // computed at the library level.
              expect(
                (inspectorServiceLocal.localClasses.keys.toList()..sort()),
                equals(
                  [
                    'AnotherClass',
                    'ExportedClass',
                    'FooClass',
                    'MyApp',
                    'MyOtherWidget',
                    'NotAWidget',
                    '_PrivateClass',
                    '_PrivateExportedClass',
                  ],
                ),
              );

              expect(
                inspectorServiceLocal.rootPackagePrefixes.toList(),
                isEmpty,
              );

              await inspectorServiceLocal.addPubRootDirectories(
                ['/usr/jacobr/foo/lib', '/usr/jacobr/bar/lib/bla'],
              );
              expect(
                inspectorServiceLocal.rootPackagePrefixes.toList(),
                isEmpty,
              );
            } finally {
              // Restore.
              await inspectorServiceLocal
                  .addPubRootDirectories(originalRootDirectories);

              await group.dispose();
            }
          },
          skip: true, // TODO(https://github.com/flutter/devtools/issues/4393)
        );

        test('local classes for bazel projects', () async {
          await env.setupEnvironment();
          final inspectorServiceLocal = inspectorService!;

          final group = inspectorServiceLocal.createObjectGroup('test-group');
          // These tests are moot if widget creation is not tracked.
          expect(await inspectorServiceLocal.isWidgetCreationTracked(), isTrue);
          await inspectorServiceLocal.addPubRootDirectories([]);
          final originalRootDirectories =
              await inspectorServiceLocal.getPubRootDirectories();
          try {
            await inspectorServiceLocal.addPubRootDirectories(
              ['/usr/me/clients/google3/foo/bar/baz/lib/src/bla'],
            );
            expect(
              inspectorServiceLocal.rootPackagePrefixes.toList(),
              equals(['foo.bar.baz.']),
            );

            await inspectorServiceLocal.addPubRootDirectories([
              '/usr/me/clients/google3/foo/bar/baz/lib/src/bla',
              '/usr/me/clients/google3/foo/core/lib',
            ]);
            expect(
              inspectorServiceLocal.rootPackagePrefixes.toList(),
              equals(
                ['foo.bar.baz.', 'foo.core.'],
              ),
            );

            // Test bazel directories without a lib directory.
            await inspectorServiceLocal.addPubRootDirectories([
              '/usr/me/clients/google3/foo/bar/baz',
              '/usr/me/clients/google3/foo/core/',
            ]);
            expect(
              inspectorServiceLocal.rootPackagePrefixes.toList(),
              equals(
                ['foo.bar.baz.', 'foo.core.'],
              ),
            );
            await inspectorServiceLocal.addPubRootDirectories([
              '/usr/me/clients/google3/third_party/dart/foo/lib/src/bla',
              '/usr/me/clients/google3/third_party/dart_src/bar/core/lib',
            ]);
            expect(
              inspectorServiceLocal.rootPackagePrefixes.toList(),
              equals(['foo.', 'bar.core.']),
            );

            await inspectorServiceLocal.addPubRootDirectories([
              '/usr/me/clients/google3/third_party/dart/foo',
              '/usr/me/clients/google3/third_party/dart_src/bar/core',
            ]);
            expect(
              inspectorServiceLocal.rootPackagePrefixes.toList(),
              equals(['foo.', 'bar.core.']),
            );
          } finally {
            // Restore.
            await inspectorServiceLocal
                .addPubRootDirectories(originalRootDirectories ?? []);

            await group.dispose();
          }
        });
      });

      test('widget tree', () async {
        await env.setupEnvironment();
        final group = inspectorService!.createObjectGroup('test-group');
        final RemoteDiagnosticsNode root =
            (await group.getRoot(FlutterTreeType.widget))!;
        // Tree only contains widgets from local app.
        expect(
          treeToDebugString(root),
          equalsIgnoringHashCodes(
            '''
[root]
 └─MyApp
   └─MaterialApp
     └─Scaffold
       ├─Center
       │ └─Text
       ├─AppBar
       │ └─Text
       └─FloatingActionButton
         └─Icon
''',
          ),
        );
        RemoteDiagnosticsNode nodeInSummaryTree =
            findNodeMatching(root, 'MaterialApp')!;
        expect(nodeInSummaryTree, isNotNull);
        expect(
          treeToDebugString(nodeInSummaryTree),
          equalsIgnoringHashCodes(
            '''
MaterialApp
 └─Scaffold
   ├─Center
   │ └─Text
   ├─AppBar
   │ └─Text
   └─FloatingActionButton
     └─Icon
''',
          ),
        );
        RemoteDiagnosticsNode nodeInDetailsTree =
            (await group.getDetailsSubtree(nodeInSummaryTree))!;
        // When flutter rolls, this string may sometimes change due to
        // implementation details.
        expect(
          treeToDebugStringTruncated(nodeInDetailsTree, 30),
          equalsGoldenIgnoringHashCodes('inspector_service_details_tree.txt'),
        );

        nodeInSummaryTree = findNodeMatching(root, 'Text')!;
        expect(nodeInSummaryTree, isNotNull);
        expect(
          treeToDebugString(nodeInSummaryTree),
          equalsIgnoringHashCodes(
            'Text\n',
          ),
        );

        nodeInDetailsTree = (await group.getDetailsSubtree(nodeInSummaryTree))!;

        expect(
          treeToDebugString(nodeInDetailsTree),
          equalsGoldenIgnoringHashCodes(
            'inspector_service_text_details_tree.txt',
          ),
        );

        expect(nodeInDetailsTree.valueRef, equals(nodeInSummaryTree.valueRef));

        await group.setSelectionInspector(nodeInDetailsTree.valueRef, true);
        final selection = (await group.getSelection(
          null,
          FlutterTreeType.widget,
          isSummaryTree: false,
        ))!;
        expect(selection, isNotNull);
        expect(selection.valueRef, equals(nodeInDetailsTree.valueRef));
        expect(
          treeToDebugString(selection),
          equalsIgnoringHashCodes(
            'Text\n'
            ' └─RichText\n',
          ),
        );

        await group.dispose();
      });

      test('enables hover eval mode by default', () async {
        await env.setupEnvironment();
        expect(inspectorService!.hoverEvalModeEnabledByDefault, isTrue);
      });

      test('disables hover eval mode by default when embedded', () async {
        await env.setupEnvironment();
        setGlobal(IdeTheme, IdeTheme(embed: true));
        expect(inspectorService!.hoverEvalModeEnabledByDefault, isFalse);
      });

// TODO(jacobr): uncomment this test once we have a more dependable golden
//      test('render tree', () async {
//        await env.setupEnvironment(
//          config: const FlutterRunConfiguration(
//            withDebugger: true,
//            trackWidgetCreation: false,
//          ),
//        );
//
//        final group = inspectorService.createObjectGroup('test-group');
//        final RemoteDiagnosticsNode root =
//            await group.getRoot(FlutterTreeType.renderObject);
//        // Tree only contains widgets from local app.
//        expect(
//          treeToDebugString(root),
//          equalsIgnoringHashCodes(
//            'RenderView#00000\n'
//            ' └─child: RenderSemanticsAnnotations#00000\n',
//          ),
//        );
//        final child = findNodeMatching(root, 'RenderSemanticsAnnotations');
//        expect(child, isNotNull);
//        final childDetailsSubtree = await group.getDetailsSubtree(child);
//        expect(
//          treeToDebugString(childDetailsSubtree),
//          equalsIgnoringHashCodes(
//            'child: RenderSemanticsAnnotations#00000\n'
//            ' │ parentData: <none>\n'
//            ' │ constraints: BoxConstraints(w=800.0, h=600.0)\n'
//            ' │ size: Size(800.0, 600.0)\n'
//            ' │\n'
//            ' └─child: RenderCustomPaint#00000\n'
//            '   │ parentData: <none> (can use size)\n'
//            '   │ constraints: BoxConstraints(w=800.0, h=600.0)\n'
//            '   │ size: Size(800.0, 600.0)\n'
//            '   │\n'
//            '   └─child: RenderPointerListener#00000\n'
//            '       parentData: <none> (can use size)\n'
//            '       constraints: BoxConstraints(w=800.0, h=600.0)\n'
//            '       size: Size(800.0, 600.0)\n'
//            '       behavior: deferToChild\n'
//            '       listeners: down, up, cancel\n',
//          ),
//        );
//
//        await group.setSelectionInspector(child.valueRef, true);
//        final selection =
//            await group.getSelection(null, FlutterTreeType.renderObject, false);
//        expect(selection, isNotNull);
//        expect(selection.valueRef, equals(child.valueRef));
//        expect(
//          treeToDebugString(selection),
//          equalsIgnoringHashCodes(
//            'RenderSemanticsAnnotations#00000\n'
//            ' └─child: RenderCustomPaint#00000\n',
//          ),
//        );
//      });

      // Run this test last as it will take a long time due to setting up the test
      // environment from scratch.
      test(
        'track widget creation off',
        () async {
          await env.setupEnvironment(
            config: const FlutterRunConfiguration(
              withDebugger: true,
              trackWidgetCreation: false,
            ),
          );

          expect(await inspectorService!.isWidgetCreationTracked(), isFalse);
        },
        skip: true,
      );
      // TODO(albertusangga): remove or fix this test

      // TODO(jacobr): add tests verifying that we can stop the running device
      // without the InspectorService spewing a bunch of errors.
    });
  } catch (e, s) {
    print(s);
  }
}

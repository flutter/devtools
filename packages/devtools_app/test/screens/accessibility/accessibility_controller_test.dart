// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'dart:ui' show SemanticsFlag;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/service/service_registrations.dart'
    as registrations;
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('AccessibilityController', () {
    late AccessibilityController controller;

    setUp(() {
      final fakeServiceConnection = FakeServiceConnectionManager();
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isFlutterWebAppNow,
      ).thenReturn(false);
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow,
      ).thenReturn(false);

      fakeServiceConnection
              .serviceManager
              .serviceExtensionResponses[registrations.enableSemantics] =
          Response.parse({})!;
      fakeServiceConnection
              .serviceManager
              .serviceExtensionResponses[registrations.getSemanticsTree] =
          Response.parse({
            'data': {
              '0': {'id': '0', 'label': 'Root'},
            },
          })!;

      setGlobal(NotificationService, NotificationService());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, fakeServiceConnection);

      controller = AccessibilityController()..init();
    });

    test('initial state', () {
      final uninitializedController = AccessibilityController();
      expect(
        uninitializedController.brightness.value,
        BrightnessOverride.system,
      );
      expect(uninitializedController.textScale.value, 1.0);
      expect(uninitializedController.boldText.value, isFalse);
      expect(uninitializedController.screenReader.value, isFalse);
      expect(uninitializedController.highContrast.value, isFalse);
      expect(uninitializedController.semanticsRoots.value, isEmpty);
      expect(uninitializedController.semanticsTreeLoading.value, isFalse);
    });

    test(
      'service extension state change updates controller brightness state',
      () {
        final fakeServiceExtensionManager =
            serviceConnection.serviceManager.serviceExtensionManager
                as FakeServiceExtensionManager;

        expect(controller.brightness.value, BrightnessOverride.system);

        // Simulate service extension state change from device to dark mode
        fakeServiceExtensionManager.fakeServiceExtensionStateChanged(
          brightnessMode.extension,
          'Brightness.dark',
        );
        expect(controller.brightness.value, BrightnessOverride.dark);

        // Simulate service extension state change from device to light mode
        fakeServiceExtensionManager.fakeServiceExtensionStateChanged(
          brightnessMode.extension,
          'Brightness.light',
        );
        expect(controller.brightness.value, BrightnessOverride.light);

        // Simulate service extension state change from device to system
        fakeServiceExtensionManager.fakeServiceExtensionStateChanged(
          brightnessMode.extension,
          'system',
        );
        expect(controller.brightness.value, BrightnessOverride.system);
      },
    );

    test(
      'setting controller brightness updates service extension state',
      () async {
        final fakeServiceExtensionManager =
            serviceConnection.serviceManager.serviceExtensionManager
                as FakeServiceExtensionManager;

        // Initial state
        expect(controller.brightness.value, BrightnessOverride.system);

        // Set to dark mode
        controller.brightness.value = BrightnessOverride.dark;

        // Wait for async operations to complete
        await Future<void>.delayed(Duration.zero);

        final darkState = fakeServiceExtensionManager
            .getServiceExtensionState(brightnessMode.extension)
            .value;
        expect(darkState.value, equals('Brightness.dark'));
        expect(darkState.enabled, isTrue);

        // Set to light mode
        controller.brightness.value = BrightnessOverride.light;
        await Future<void>.delayed(Duration.zero);

        final lightState = fakeServiceExtensionManager
            .getServiceExtensionState(brightnessMode.extension)
            .value;
        expect(lightState.value, equals('Brightness.light'));
        expect(lightState.enabled, isTrue);

        // Set to system
        controller.brightness.value = BrightnessOverride.system;
        await Future<void>.delayed(Duration.zero);

        final systemState = fakeServiceExtensionManager
            .getServiceExtensionState(brightnessMode.extension)
            .value;
        expect(systemState.value, equals('system'));
        expect(systemState.enabled, isFalse);
      },
    );

    test('SemanticsNodeModel properties and shallowCopy', () {
      final child = SemanticsNodeModel(
        id: '1',
        label: 'Child Node',
        flags: {SemanticsFlag.isButton, SemanticsFlag.hasCheckedState},
        widgetName: 'ElevatedButton',
      );
      final parent = SemanticsNodeModel(
        id: '0',
        label: 'Parent Node',
        flags: {SemanticsFlag.isHeader},
        widgetName: 'Column',
      )..addChild(child);

      expect(parent.children, hasLength(1));
      expect(parent.children.first.id, equals('1'));

      final copy = child.shallowCopy();
      expect(copy.id, equals('1'));
      expect(copy.label, equals('Child Node'));
      expect(
        copy.flags,
        equals({SemanticsFlag.isButton, SemanticsFlag.hasCheckedState}),
      );
      expect(copy.widgetName, equals('ElevatedButton'));
      expect(copy.children, isEmpty);
    });

    test(
      'loadSemanticsTree sets error state when no main isolate connected',
      () async {
        final fakeServiceConnection = _NullIsolateServiceConnectionManager();
        setGlobal(ServiceConnectionManager, fakeServiceConnection);

        final testController = AccessibilityController();
        expect(testController.semanticsTreeError.value, isNull);
        await testController.loadSemanticsTree();
        expect(
          testController.semanticsTreeError.value,
          equals('Failed to load semantics tree: no connected application.'),
        );
        expect(testController.semanticsTreeLoading.value, isFalse);
        expect(testController.semanticsRoots.value, isEmpty);
      },
    );

    test(
      'loadSemanticsTree sets error state when service extension returns error',
      () async {
        final fakeServiceManager =
            serviceConnection.serviceManager as FakeServiceManager;
        fakeServiceManager.serviceExtensionResponses[registrations
            .enableSemantics] = Response.parse(
          {},
        )!;
        fakeServiceManager.serviceExtensionResponses[registrations
            .getSemanticsTree] = Response.parse({
          'error': 'Semantics not enabled.',
        })!;

        final testController = AccessibilityController();
        await testController.loadSemanticsTree();

        expect(
          testController.semanticsTreeError.value,
          equals(
            'Failed to load semantics tree: Exception: Semantics not enabled.',
          ),
        );
        expect(testController.semanticsRoots.value, isEmpty);
      },
    );

    test(
      'loadSemanticsTree parses full SemanticsNode.toJson format with multiple nodes',
      () async {
        final fakeServiceManager =
            serviceConnection.serviceManager as FakeServiceManager;
        fakeServiceManager.serviceExtensionResponses[registrations
            .enableSemantics] = Response.parse(
          {},
        )!;
        fakeServiceManager.serviceExtensionResponses[registrations
            .getSemanticsTree] = Response.parse({
          'data': {
            '0': {
              'id': 0,
              'label': 'Root View',
              'value': 'Main Screen',
              'hint': '',
              'tooltip': '',
              'increasedValue': '',
              'decreasedValue': '',
              'flags': ['hasEnabledState', 'isEnabled'],
              'actions': [],
              'rect': {
                'left': 0.0,
                'top': 0.0,
                'width': 390.0,
                'height': 844.0,
              },
              'transform': [
                1.0,
                0.0,
                0.0,
                0.0,
                0.0,
                1.0,
                0.0,
                0.0,
                0.0,
                0.0,
                1.0,
                0.0,
                0.0,
                0.0,
                0.0,
                1.0,
              ],
              'childrenInTraversalOrder': [1, 2],
              'childrenInHitTestOrder': [2, 1],
            },
            '1': {
              'id': 1,
              'label': 'Settings Header',
              'flags': ['isHeader'],
              'actions': [],
              'rect': {
                'left': 16.0,
                'top': 40.0,
                'width': 358.0,
                'height': 32.0,
              },
            },
            '2': {
              'id': 2,
              'label': 'Search Input',
              'value': 'Flutter',
              'hint': 'Enter search query',
              'tooltip': 'Search field',
              'flags': ['isTextField'],
              'actions': ['tap', 'setSelection'],
              'rect': {
                'left': 16.0,
                'top': 88.0,
                'width': 358.0,
                'height': 48.0,
              },
              'childrenInTraversalOrder': [3],
              'childrenInHitTestOrder': [3],
            },
            '3': {
              'id': 3,
              'label': 'Clear Text',
              'tooltip': 'Clear input content',
              'flags': ['isButton', 'hasCheckedState'],
              'actions': ['tap'],
              'rect': {
                'left': 330.0,
                'top': 96.0,
                'width': 32.0,
                'height': 32.0,
              },
            },
          },
        })!;

        final testController = AccessibilityController();
        await testController.loadSemanticsTree();

        expect(testController.semanticsRoots.value, hasLength(1));
        final root = testController.semanticsRoots.value.first;
        expect(root.id, equals('0'));
        expect(root.label, equals('Root View'));
        expect(
          root.flags,
          equals({SemanticsFlag.hasEnabledState, SemanticsFlag.isEnabled}),
        );
        expect(root.children, hasLength(2));

        // Node 1: Settings Header
        final headerNode = root.children[0];
        expect(headerNode.id, equals('1'));
        expect(headerNode.label, equals('Settings Header'));
        expect(headerNode.flags, equals({SemanticsFlag.isHeader}));
        expect(headerNode.children, isEmpty);

        // Node 2: Search Input
        final searchNode = root.children[1];
        expect(searchNode.id, equals('2'));
        expect(searchNode.label, equals('Search Input'));
        expect(searchNode.flags, equals({SemanticsFlag.isTextField}));
        expect(searchNode.children, hasLength(1));

        // Node 3: Clear Text Button (child of Node 2)
        final clearButtonNode = searchNode.children.first;
        expect(clearButtonNode.id, equals('3'));
        expect(clearButtonNode.label, equals('Clear Text'));
        expect(
          clearButtonNode.flags,
          equals({SemanticsFlag.isButton, SemanticsFlag.hasCheckedState}),
        );
        expect(clearButtonNode.children, isEmpty);
      },
    );

    test(
      'loadSemanticsTree parses flat nodes map and builds child hierarchy',
      () async {
        final fakeServiceManager =
            serviceConnection.serviceManager as FakeServiceManager;
        fakeServiceManager.serviceExtensionResponses[registrations
            .enableSemantics] = Response.parse(
          {},
        )!;
        fakeServiceManager.serviceExtensionResponses[registrations
            .getSemanticsTree] = Response.parse({
          'data': {
            '0': {
              'id': 0,
              'label': 'Root',
              'childrenInTraversalOrder': [1],
            },
            '1': {
              'id': 1,
              'label': 'Child full',
              'flags': ['isButton'],
            },
          },
        })!;

        final testController = AccessibilityController();
        await testController.loadSemanticsTree();

        expect(testController.semanticsRoots.value, hasLength(1));
        final root = testController.semanticsRoots.value.first;
        expect(root.id, equals('0'));
        expect(root.label, equals('Root'));
        expect(root.children, hasLength(1));
        expect(root.children.first.id, equals('1'));
        expect(root.children.first.label, equals('Child full'));
        expect(root.children.first.flags, equals({SemanticsFlag.isButton}));
      },
    );

    test('dispose calls disposeSemantics', () async {
      final recordingServiceConnection = _RecordingServiceConnectionManager();
      setGlobal(ServiceConnectionManager, recordingServiceConnection);

      final testController = AccessibilityController();
      testController.dispose();
      await Future<void>.delayed(Duration.zero);

      final calls =
          (recordingServiceConnection.serviceManager
                  as _RecordingServiceManager)
              .recordedCalls;
      expect(
        calls.any((call) => call.$1 == registrations.disposeSemantics),
        isTrue,
      );
    });
  });
}

class _RecordingServiceConnectionManager extends FakeServiceConnectionManager {
  @override
  late final serviceManager = _RecordingServiceManager();
}

// ignore: subtype_of_sealed_class, fake for testing.
class _RecordingServiceManager extends FakeServiceManager {
  final recordedCalls = <(String, Map<String, dynamic>?)>[];

  @override
  Future<Response> callServiceExtensionOnMainIsolate(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    recordedCalls.add((method, args));
    return serviceExtensionResponses[method] ?? Response.parse({})!;
  }
}

class _NullIsolateServiceConnectionManager
    extends FakeServiceConnectionManager {
  @override
  late final serviceManager = _NullIsolateServiceManager();
}

// ignore: subtype_of_sealed_class, fake for testing.
class _NullIsolateServiceManager extends FakeServiceManager {
  @override
  late final isolateManager = _NullIsolateManager();
}

base class _NullIsolateManager extends FakeIsolateManager {
  @override
  ValueListenable<IsolateRef?> get mainIsolate =>
      ValueNotifier<IsolateRef?>(null);
}

// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/src/service/isolate_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

/// Minimal fake VmService for IsolateManager tests.
class _FakeVmService extends Fake implements VmService {
  /// Map of isolate id -> Isolate to return from getIsolate().
  final Map<String, Isolate> isolates;

  _FakeVmService(this.isolates);

  @override
  Stream<Event> get onIsolateEvent => const Stream.empty();

  @override
  Stream<Event> get onDebugEvent => const Stream.empty();

  @override
  Future<Isolate> getIsolate(String isolateId) async {
    return isolates[isolateId] ??
        Isolate.parse({
          'id': isolateId,
          'runnable': true,
          'extensionRPCs': <String>[],
        })!;
  }

  @override
  Future<Success> resume(String isolateId, {String? step, int? frameIndex}) =>
      Future.value(Success());
}

/// Creates a minimal runnable [Isolate] for a given [IsolateRef].
Isolate _makeIsolate(IsolateRef ref, {String? rootLibraryUri}) {
  final json = <String, Object?>{
    'id': ref.id,
    'name': ref.name,
    'type': '@Isolate',
    'runnable': true,
    'extensionRPCs': <String>[],
    if (rootLibraryUri != null)
      'rootLib': {
        'type': '@Library',
        'id': 'libraries/0',
        'uri': rootLibraryUri,
      },
  };

  return Isolate.parse(json)!;
}

/// Creates an [IsolateRef] with the given name and id.
IsolateRef _makeRef(String name, String id) {
  return IsolateRef.parse({'name': name, 'id': id, 'isSystemIsolate': false})!;
}

void main() {
  group('IsolateManager._computeMainIsolate', () {
    late IsolateManager manager;

    setUp(() {
      manager = IsolateManager();
    });

    tearDown(() {
      manager.handleVmServiceClosed();
    });

    test(
      'selects test_suite isolate instead of test runner when running tests',
      () async {
        // Simulates the isolate list seen when connecting to a test run:
        // - 'main' is the test runner isolate (wrong choice)
        // - 'test_suite:...' is where user code actually runs (correct choice)
        // - 'vm-service' is infrastructure
        final testRunnerRef = _makeRef('main', 'isolates/1');
        final testSuiteRef = _makeRef(
          'test_suite:file:///tmp/dart_test.kernel.dill',
          'isolates/2',
        );
        final vmServiceRef = _makeRef('vm-service', 'isolates/3');

        final fakeService = _FakeVmService({
          'isolates/1': _makeIsolate(testRunnerRef),
          'isolates/2': _makeIsolate(testSuiteRef),
          'isolates/3': _makeIsolate(vmServiceRef),
        });

        manager.vmServiceOpened(fakeService);
        await manager.init([testRunnerRef, testSuiteRef, vmServiceRef]);

        expect(
          manager.selectedIsolate.value?.name,
          equals('test_suite:file:///tmp/dart_test.kernel.dill'),
          reason:
              'Should auto-select the test_suite isolate, not the test runner',
        );
        expect(
          manager.mainIsolate.value?.name,
          equals('test_suite:file:///tmp/dart_test.kernel.dill'),
          reason:
              'Main isolate should also resolve to the test_suite isolate',
        );
      },
    );

    test('selects main isolate for normal (non-test) app runs', () async {
      final mainRef = _makeRef('main', 'isolates/1');
      final vmServiceRef = _makeRef('vm-service', 'isolates/2');

      final fakeService = _FakeVmService({
        'isolates/1': _makeIsolate(mainRef),
        'isolates/2': _makeIsolate(vmServiceRef),
      });

      manager.vmServiceOpened(fakeService);
      await manager.init([mainRef, vmServiceRef]);

      expect(
        manager.selectedIsolate.value?.name,
        equals('main'),
        reason: 'Should select the main isolate for normal app runs',
      );
    });

    test('selects isolate containing :main( for dart scripts', () async {
      final scriptRef = _makeRef('foo.dart:main()', 'isolates/1');

      final fakeService = _FakeVmService({
        'isolates/1': _makeIsolate(scriptRef),
      });

      manager.vmServiceOpened(fakeService);
      await manager.init([scriptRef]);

      expect(
        manager.selectedIsolate.value?.name,
        equals('foo.dart:main()'),
      );
    });

    test(
      'selects test isolate by root library when test_suite prefix is absent',
      () async {
        final testRunnerRef = _makeRef('main', 'isolates/1');
        final userTestRef = _makeRef('isolate-2', 'isolates/2');
        final vmServiceRef = _makeRef('vm-service', 'isolates/3');

        final fakeService = _FakeVmService({
          'isolates/1': _makeIsolate(
            testRunnerRef,
            rootLibraryUri: 'file:///tmp/dart_test.kernel.abcd/test.dart',
          ),
          'isolates/2': _makeIsolate(
            userTestRef,
            rootLibraryUri: 'package:my_app/foo_test.dart',
          ),
          'isolates/3': _makeIsolate(
            vmServiceRef,
            rootLibraryUri: 'dart:developer',
          ),
        });

        manager.vmServiceOpened(fakeService);
        await manager.init([testRunnerRef, userTestRef, vmServiceRef]);

        expect(
          manager.selectedIsolate.value?.name,
          equals('isolate-2'),
          reason:
              'Should choose user test isolate using root library metadata',
        );
        expect(
          manager.mainIsolate.value?.name,
          equals('isolate-2'),
        );
      },
    );
  });
}

// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart' hide SentinelException;
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('forEachIsolateHelper', () {
    test('calls callback for each isolate', () async {
      final isolates = [
        IsolateRef(id: 'isolate_1', number: '1', name: 'main_1'),
        IsolateRef(id: 'isolate_2', number: '2', name: 'main_2'),
      ];
      final fakeService = _FakeVmService(isolates: isolates);
      final visited = <String>[];
      await forEachIsolateHelper(fakeService, (isolate) async {
        visited.add(isolate.id!);
      });
      expect(visited, equals(['isolate_1', 'isolate_2']));
    });

    test('is a no-op when isolates list is empty or null', () async {
      final emptyService = _FakeVmService(isolates: []);
      var called = false;
      await forEachIsolateHelper(emptyService, (isolate) async {
        called = true;
      });
      expect(called, isFalse);

      final nullService = _FakeVmService(isolates: null);
      await forEachIsolateHelper(nullService, (isolate) async {
        called = true;
      });
      expect(called, isFalse);
    });

    test(
      'rethrows RPCError directly without wrapping in ParallelWaitError',
      () async {
        final isolates = [
          IsolateRef(id: 'isolate_1', number: '1', name: 'main_1'),
          IsolateRef(id: 'isolate_2', number: '2', name: 'main_2'),
        ];
        final fakeService = _FakeVmService(isolates: isolates);
        final error = RPCError(
          'ext.dart.io.getSocketProfile',
          RPCErrorKind.kServiceDisappeared.code,
          'Service has disappeared',
        );

        await expectLater(
          () => forEachIsolateHelper(
            fakeService,
            (isolate) => Future<void>.error(error),
          ),
          throwsA(same(error)),
        );
      },
    );

    test(
      'rethrows SentinelException directly without wrapping in ParallelWaitError',
      () async {
        final isolates = [
          IsolateRef(id: 'isolate_1', number: '1', name: 'main_1'),
        ];
        final fakeService = _FakeVmService(isolates: isolates);
        final sentinel = SentinelException.parse('getIsolate', {
          'type': 'Sentinel',
          'kind': 'Collected',
          'valueAsString': '<collected>',
        });

        await expectLater(
          () => forEachIsolateHelper(
            fakeService,
            (isolate) => Future<void>.error(sentinel),
          ),
          throwsA(same(sentinel)),
        );
      },
    );

    test(
      'VmServiceExtension.forEachIsolate delegates to forEachIsolateHelper',
      () async {
        final isolates = [
          IsolateRef(id: 'isolate_1', number: '1', name: 'main_1'),
        ];
        final fakeService = _FakeVmService(isolates: isolates);
        final visited = <String>[];
        await fakeService.forEachIsolate((isolate) async {
          visited.add(isolate.id!);
        });
        expect(visited, equals(['isolate_1']));
      },
    );
  });
}

class _FakeVmService extends Fake implements VmService {
  _FakeVmService({required this.isolates});

  final List<IsolateRef>? isolates;

  @override
  Future<VM> getVM() async => VM(isolates: isolates);
}

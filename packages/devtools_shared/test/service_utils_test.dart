// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_shared/src/service_utils.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('normalizeVmServiceUri', () {
    test('normalizes simple URIs', () {
      expect(
        normalizeVmServiceUri('http://127.0.0.1:60667/72K34Xmq0X0=').toString(),
        equals('http://127.0.0.1:60667/72K34Xmq0X0='),
      );
      expect(
        normalizeVmServiceUri(
          'http://127.0.0.1:60667/72K34Xmq0X0=/   ',
        ).toString(),
        equals('http://127.0.0.1:60667/72K34Xmq0X0=/'),
      );
      expect(
        normalizeVmServiceUri('http://127.0.0.1:60667').toString(),
        equals('http://127.0.0.1:60667'),
      );
      expect(
        normalizeVmServiceUri('http://127.0.0.1:60667/').toString(),
        equals('http://127.0.0.1:60667/'),
      );
    });

    test('properly strips leading whitespace and trailing URI fragments', () {
      expect(
        normalizeVmServiceUri(
          '  http://127.0.0.1:60667/72K34Xmq0X0=/#/vm',
        ).toString(),
        equals('http://127.0.0.1:60667/72K34Xmq0X0=/'),
      );
      expect(
        normalizeVmServiceUri(
          '  http://127.0.0.1:60667/72K34Xmq0X0=/#/vm  ',
        ).toString(),
        equals('http://127.0.0.1:60667/72K34Xmq0X0=/'),
      );
    });

    test('properly handles encoded urls', () {
      expect(
        normalizeVmServiceUri(
          'http%3A%2F%2F127.0.0.1%3A58824%2FCnvgRrQJG7w%3D',
        ).toString(),
        equals('http://127.0.0.1:58824/CnvgRrQJG7w='),
      );

      expect(
        normalizeVmServiceUri(
          'http%3A%2F%2F127.0.0.1%3A58824%2FCnvgRrQJG7w%3D  ',
        ).toString(),
        equals('http://127.0.0.1:58824/CnvgRrQJG7w='),
      );

      expect(
        normalizeVmServiceUri(
          '  http%3A%2F%2F127.0.0.1%3A58824%2FCnvgRrQJG7w%3D   ',
        ).toString(),
        equals('http://127.0.0.1:58824/CnvgRrQJG7w='),
      );
    });

    test('handles prefixed devtools server uris', () {
      expect(
        normalizeVmServiceUri(
          'http://127.0.0.1:9101?uri=http%3A%2F%2F127.0.0.1%3A56142%2FHOwgrxalK00%3D%2F',
        ).toString(),
        equals('http://127.0.0.1:56142/HOwgrxalK00=/'),
      );
    });

    test('Returns null when given a non-absolute url', () {
      expect(normalizeVmServiceUri('my/page'), null);
    });

    test('allows valid loopback URIs with allowed schemes', () {
      expect(
        normalizeVmServiceUri('http://127.0.0.1:8181').toString(),
        equals('http://127.0.0.1:8181'),
      );
      expect(
        normalizeVmServiceUri('ws://localhost:8181/ws').toString(),
        equals('ws://localhost:8181/ws'),
      );
      expect(
        normalizeVmServiceUri('http://[::1]:8181').toString(),
        equals('http://[::1]:8181'),
      );
      expect(
        normalizeVmServiceUri('https://127.0.0.1:8181').toString(),
        equals('https://127.0.0.1:8181'),
      );
      expect(
        normalizeVmServiceUri('sse://127.0.0.1:8181').toString(),
        equals('sse://127.0.0.1:8181'),
      );
      expect(
        normalizeVmServiceUri('wss://localhost:8181/ws').toString(),
        equals('wss://localhost:8181/ws'),
      );
      expect(
        normalizeVmServiceUri('sses://127.0.0.2:8181/sse').toString(),
        equals('sses://127.0.0.2:8181/sse'),
      );
    });

    test('returns null for non-loopback hosts', () {
      expect(normalizeVmServiceUri('ws://attacker.evil/fake'), isNull);
      expect(normalizeVmServiceUri('http://192.168.1.1:8181'), isNull);
      expect(normalizeVmServiceUri('http://10.0.0.1:8181'), isNull);
      expect(normalizeVmServiceUri('http://127.256.0.1:8181'), isNull);
      expect(normalizeVmServiceUri('http://[::2]:8181'), isNull);
    });

    test('returns null for disallowed schemes', () {
      expect(normalizeVmServiceUri('file:///etc/passwd'), isNull);
      expect(normalizeVmServiceUri('javascript:alert(1)'), isNull);
      expect(normalizeVmServiceUri('ftp://127.0.0.1:8181/'), isNull);
    });
  });

  group('VmServicePackageRootExtension', () {
    test('fetches full string when packageConfigLocation is truncated', () async {
      final longPackageRoot =
          'file:///Users/developer/${List.filled(6, 'very_long_directory_name').join('/')}/my_app';
      final fullPackageConfigUri =
          '$longPackageRoot/.dart_tool/package_config.json';
      expect(fullPackageConfigUri.length, greaterThan(128));

      final fakeVmService = _FakeVmServiceForTestTarget(
        fullPackageConfigUri: fullPackageConfigUri,
      );

      final rootDir = await fakeVmService.rootPackageDirectoryForMainIsolate();
      expect(rootDir, equals(longPackageRoot));
      expect(fakeVmService.requestedFullStringOffset, equals(0));
      expect(
        fakeVmService.requestedFullStringCount,
        equals(fullPackageConfigUri.length),
      );
    });

    test('returns null when test target package root lookup fails', () async {
      final fakeVmService = _FakeVmServiceForTestTarget(
        fullPackageConfigUri: null,
      );

      final rootDir = await fakeVmService.rootPackageDirectoryForMainIsolate();
      expect(rootDir, isNull);
    });

    test(
      'skips isolates that throw SentinelException during getIsolate',
      () async {
        final fakeVmService = _FakeVmServiceWithIsolates(
          isolateRefs: [
            IsolateRef(id: 'isolates/exited', name: 'exited'),
            IsolateRef(id: 'isolates/main', name: 'main'),
          ],
          isolatesById: {
            'isolates/main': Isolate(
              id: 'isolates/main',
              name: 'main',
              rootLib: LibraryRef(
                id: 'libraries/1',
                uri: 'file:///Users/developer/my_app/lib/main.dart',
              ),
            ),
          },
        );

        final rootDir = await fakeVmService
            .rootPackageDirectoryForMainIsolate();
        expect(rootDir, equals('file:///Users/developer/my_app'));
      },
    );

    test('returns null when all isolates throw SentinelException', () async {
      final fakeVmService = _FakeVmServiceWithIsolates(
        isolateRefs: [IsolateRef(id: 'isolates/exited', name: 'exited')],
        isolatesById: const {},
      );

      final rootDir = await fakeVmService.rootPackageDirectoryForMainIsolate();
      expect(rootDir, isNull);
    });

    test('handles isolates with null name without throwing', () async {
      final fakeVmService = _FakeVmServiceWithIsolates(
        isolateRefs: [IsolateRef(id: 'isolates/unnamed')],
        isolatesById: {
          'isolates/unnamed': Isolate(
            id: 'isolates/unnamed',
            rootLib: LibraryRef(
              id: 'libraries/1',
              uri: 'file:///Users/developer/my_app/lib/main.dart',
            ),
          ),
        },
      );

      final rootDir = await fakeVmService.rootPackageDirectoryForMainIsolate();
      expect(rootDir, equals('file:///Users/developer/my_app'));
    });
  });
}

class _FakeVmServiceForTestTarget extends VmService {
  _FakeVmServiceForTestTarget({required this.fullPackageConfigUri})
    : super(const Stream.empty(), (_) {});

  final String? fullPackageConfigUri;
  int? requestedFullStringOffset;
  int? requestedFullStringCount;

  static const _isolateId = 'isolates/1';
  static const _rootLibId = 'libraries/1';
  static const _packageConfigStringId = 'objects/package_config_string';

  @override
  Future<VM> getVM() async => VM(
    isolates: [IsolateRef(id: _isolateId, name: 'main')],
  );

  @override
  Future<Isolate> getIsolate(String isolateId) async => Isolate(
    id: _isolateId,
    name: 'main',
    rootLib: LibraryRef(
      id: _rootLibId,
      uri: 'file:///tmp/test_runner/main.dart',
    ),
  );

  @override
  Future<UriList> lookupResolvedPackageUris(
    String isolateId,
    List<String> uris, {
    bool? local,
  }) async => UriList(uris: uris);

  @override
  Future<Response> evaluate(
    String isolateId,
    String targetId,
    String expression, {
    Map<String, String>? scope,
    bool? disableBreakpoints,
    String? idZoneId,
  }) async {
    expect(expression, equals('packageConfigLocation'));
    final uri = fullPackageConfigUri;
    if (uri == null) {
      throw RPCError('evaluate', 113, 'Expression compilation error');
    }
    return InstanceRef(
      id: _packageConfigStringId,
      kind: InstanceKind.kString,
      valueAsString: uri.substring(0, 128),
      valueAsStringIsTruncated: true,
      length: uri.length,
    );
  }

  @override
  Future<Obj> getObject(
    String isolateId,
    String objectId, {
    int? offset,
    int? count,
    String? idZoneId,
  }) async {
    if (objectId == _rootLibId) {
      return Library(id: _rootLibId, dependencies: const []);
    }
    if (objectId == _packageConfigStringId) {
      requestedFullStringOffset = offset;
      requestedFullStringCount = count;
      return Instance(
        id: _packageConfigStringId,
        kind: InstanceKind.kString,
        valueAsString: fullPackageConfigUri,
        valueAsStringIsTruncated: false,
        length: fullPackageConfigUri!.length,
      );
    }
    throw UnimplementedError('Unexpected getObject($objectId)');
  }
}

class _FakeVmServiceWithIsolates extends VmService {
  _FakeVmServiceWithIsolates({
    required this.isolateRefs,
    required this.isolatesById,
  }) : super(const Stream.empty(), (_) {});

  final List<IsolateRef> isolateRefs;
  final Map<String, Isolate> isolatesById;

  @override
  Future<VM> getVM() async => VM(isolates: isolateRefs);

  @override
  Future<Isolate> getIsolate(String isolateId) async {
    final isolate = isolatesById[isolateId];
    if (isolate == null) {
      throw SentinelException.parse('getIsolate', {
        'type': 'Sentinel',
        'kind': SentinelKind.kCollected,
        'valueAsString': '<collected>',
      });
    }
    return isolate;
  }

  @override
  Future<UriList> lookupResolvedPackageUris(
    String isolateId,
    List<String> uris, {
    bool? local,
  }) async => UriList(uris: uris);
}

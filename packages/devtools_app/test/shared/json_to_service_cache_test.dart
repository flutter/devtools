// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/service/json_to_service_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('JsonToServiceCache', () {
    test('basic', () {
      const data = <String, Object?>{
        'id': 1,
        'map': {
          'foo': 'bar',
        },
        'list': [
          1,
          '2',
          true,
          null,
        ],
        'aNullValue': null,
      };

      final cache = JsonToServiceCache();
      expect(cache.length, 0);

      void ensureIsInCache(Instance instance) {
        final cached = cache.getObject(objectId: instance.id!);
        expect(cached, isNotNull);
        expect(identical(instance, cached), isTrue);
      }

      final instance = cache.insertJsonObject(data);
      ensureIsInCache(instance);
      expect(cache.length, 12);

      expect(instance.kind, InstanceKind.kMap);
      final associations = instance.associations!;
      expect(associations.length, 4);

      // 'id': 1
      final idKey = associations[0].key as Instance;
      expect(idKey.kind, InstanceKind.kString);
      expect(idKey.valueAsString, 'id');
      ensureIsInCache(idKey);
      final idValue = associations[0].value as Instance;
      expect(idValue.kind, InstanceKind.kInt);
      expect(idValue.valueAsString, '1');
      ensureIsInCache(idValue);

      // 'map': { ... }
      final mapKey = associations[1].key as Instance;
      expect(mapKey.kind, InstanceKind.kString);
      expect(mapKey.valueAsString, 'map');
      ensureIsInCache(mapKey);
      final mapValue = associations[1].value as Instance;
      expect(mapValue.kind, InstanceKind.kMap);
      ensureIsInCache(mapValue);
      {
        final contents = mapValue.associations!;
        expect(contents, hasLength(1));
        final foo = contents[0].key as Instance;
        expect(foo.kind, InstanceKind.kString);
        expect(foo.valueAsString, 'foo');
        ensureIsInCache(foo);
        final bar = contents[0].value as Instance;
        expect(bar.kind, InstanceKind.kString);
        expect(bar.valueAsString, 'bar');
        ensureIsInCache(bar);
      }

      // 'list': [ ... ]
      final listKey = associations[2].key as Instance;
      expect(listKey.kind, InstanceKind.kString);
      expect(listKey.valueAsString, 'list');
      ensureIsInCache(listKey);
      final listValue = associations[2].value as Instance;
      expect(listValue.kind, InstanceKind.kList);
      ensureIsInCache(listValue);
      {
        final contents = listValue.elements!.cast<Instance>();
        expect(contents, hasLength(4));
        expect(contents[0].kind, InstanceKind.kInt);
        expect(contents[0].valueAsString, '1');
        ensureIsInCache(contents[0]);
        expect(contents[1].kind, InstanceKind.kString);
        expect(contents[1].valueAsString, '2');
        ensureIsInCache(contents[1]);
        expect(contents[2].kind, InstanceKind.kBool);
        expect(contents[2].valueAsString, 'true');
        ensureIsInCache(contents[2]);
        expect(contents[3].kind, InstanceKind.kNull);
        ensureIsInCache(contents[3]);
      }
      cache.removeJsonObject(instance);
      expect(cache.length, 0);
    });

    test('sub-collection support', () {
      final data = <String, Object?>{
        'list': [
          for (int i = 0; i < 10; ++i) i,
        ],
        'map': {
          for (int i = 0; i < 10; ++i) '$i': i,
        },
      };
      final cache = JsonToServiceCache();
      final root = cache.insertJsonObject(data);

      final list = root.associations![0].value as Instance;
      expect(list.kind, InstanceKind.kList);
      final sublist = cache.getObject(objectId: list.id!, offset: 2, count: 5)!;
      expect(sublist.count, 5);
      for (int i = 0; i < sublist.count!; ++i) {
        final element = sublist.elements![i] as Instance;
        expect(element.valueAsString, (i + 2).toString());
      }

      final map = root.associations![1].value as Instance;
      expect(map.kind, InstanceKind.kMap);
      final submap = cache.getObject(objectId: map.id!, offset: 2, count: 5)!;
      expect(submap.count, 5);
      for (int i = 0; i < submap.count!; ++i) {
        final association = submap.associations![i];
        expect(
          (association.key as Instance).valueAsString,
          (i + 2).toString(),
        );
        expect(
          (association.value as Instance).valueAsString,
          (i + 2).toString(),
        );
      }
    });
  });

  test('instanceToJson converts Instances back to the JSON that created them',
      () {
    const data = <String, Object?>{
      'id': 1,
      'map': {
        'foo': 'bar',
        'baz': [
          'a',
          null,
        ],
      },
      'list': [
        [
          7,
          '8',
          9.0,
        ],
        1,
        '2',
        4.9,
        true,
        null,
        {
          'a': 'b',
          'c': 'd',
        },
      ],
      'aNullValue': null,
    };

    final cache = JsonToServiceCache();
    final root = cache.insertJsonObject(data);

    final rootConvertedBackToJson = cache.instanceToJson(root);

    expect(rootConvertedBackToJson, data);
  });
}

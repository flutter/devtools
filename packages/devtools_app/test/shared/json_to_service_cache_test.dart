// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/service/json_to_service_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('JsonToServiceCache', () {
    test('basic', () {
      const data = <String, dynamic>{
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
      expect(cache.length, 11);

      expect(instance.kind, InstanceKind.kMap);
      final associations = instance.associations!;
      expect(associations.length, 3);

      // 'id': 1
      expect(associations[0].key.kind, InstanceKind.kString);
      expect(associations[0].key.valueAsString, 'id');
      ensureIsInCache(associations[0].key);
      expect(associations[0].value.kind, InstanceKind.kInt);
      expect(associations[0].value.valueAsString, '1');
      ensureIsInCache(associations[0].value);

      // 'map': { ... }
      expect(associations[1].key.kind, InstanceKind.kString);
      expect(associations[1].key.valueAsString, 'map');
      ensureIsInCache(associations[1].key);
      expect(associations[1].value.kind, InstanceKind.kMap);
      ensureIsInCache(associations[1].value);
      {
        final contents = associations[1].value.associations!;
        expect(contents.length, 1);
        expect(contents[0].key.kind, InstanceKind.kString);
        expect(contents[0].key.valueAsString, 'foo');
        ensureIsInCache(contents[0].key);
        expect(contents[0].value.kind, InstanceKind.kString);
        expect(contents[0].value.valueAsString, 'bar');
        ensureIsInCache(contents[0].value);
      }

      // 'list': [ ... ]
      expect(associations[2].key.kind, InstanceKind.kString);
      expect(associations[2].key.valueAsString, 'list');
      ensureIsInCache(associations[2].key);
      expect(associations[2].value.kind, InstanceKind.kList);
      ensureIsInCache(associations[2].value);
      {
        final contents = associations[2].value.elements!;
        expect(contents.length, 4);
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
      final data = <String, dynamic>{
        'list': [
          for (int i = 0; i < 10; ++i) i,
        ],
        'map': {
          for (int i = 0; i < 10; ++i) '$i': i,
        },
      };
      final cache = JsonToServiceCache();
      final root = cache.insertJsonObject(data);

      final list = root.associations![0].value;
      expect(list.kind, InstanceKind.kList);
      final sublist = cache.getObject(objectId: list.id!, offset: 2, count: 5)!;
      expect(sublist.count, 5);
      for (int i = 0; i < sublist.count!; ++i) {
        expect(sublist.elements![i].valueAsString, (i + 2).toString());
      }

      final map = root.associations![1].value;
      expect(map.kind, InstanceKind.kMap);
      final submap = cache.getObject(objectId: map.id!, offset: 2, count: 5)!;
      expect(submap.count, 5);
      for (int i = 0; i < submap.count!; ++i) {
        expect(submap.associations![i].key.valueAsString, (i + 2).toString());
        expect(submap.associations![i].value.valueAsString, (i + 2).toString());
      }
    });
  });
}

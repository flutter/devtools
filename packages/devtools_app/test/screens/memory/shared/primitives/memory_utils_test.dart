// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/screens/memory/shared/primitives/memory_utils.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app_shared/service.dart' show RootInfo;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RootInfoMemoryExtension.rootPackagePrefix', () {
    for (final (rootLibrary, expectedPrefix) in const [
      ('package:my_app/main.dart', 'package:my_app'),
      ('package:my_app/src/nested/file.dart', 'package:my_app'),
      ('package:my_app', 'package:my_app'),
      // The root library of a Dart CLI app started with `dart run`.
      ('file:///app/bin/main.dart', 'file:'),
      ('org-dartlang-app:///lib/main.dart', 'org-dartlang-app:'),
      (null, null),
    ]) {
      test('is $expectedPrefix for $rootLibrary', () {
        expect(RootInfo(rootLibrary).rootPackagePrefix, expectedPrefix);
      });
    }

    test('classifies classes of a file: root library as project classes', () {
      const rootLibrary = 'file:///app/bin/main.dart';
      final heapClass = HeapClassName(
        library: rootLibrary,
        className: 'MyClass',
      );

      expect(
        heapClass.classType(RootInfo(rootLibrary).rootPackagePrefix),
        ClassType.rootPackage,
      );
    });

    test('keeps classes of other libraries out of the project', () {
      final rootPrefix = RootInfo('package:my_app/main.dart').rootPackagePrefix;

      expect(
        HeapClassName(
          library: 'package:my_app/src/model.dart',
          className: 'Model',
        ).classType(rootPrefix),
        ClassType.rootPackage,
      );
      expect(
        HeapClassName(
          library: 'package:other_package/other.dart',
          className: 'Other',
        ).classType(rootPrefix),
        ClassType.dependency,
      );
    });
  });
}

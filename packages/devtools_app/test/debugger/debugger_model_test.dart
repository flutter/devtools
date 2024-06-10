// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('debugger_model', () {
    final ref1 = ScriptRef(uri: 'package:foo', id: 'id-1');
    final ref2 = ScriptRef(uri: 'package:foo/foo.dart', id: 'id-2');
    final ref3 = ScriptRef(uri: 'package:bar/bar.dart', id: 'id-3');
    final ref4 = ScriptRef(uri: 'package:bar/baz.dart', id: 'id-4');

    group('FileNode', () {
      test('handles an empty list', () {
        final roots = FileNode.createRootsFrom([]);
        expect(roots, isEmpty);
      });

      test('a one item list', () {
        final roots = FileNode.createRootsFrom([ref2]);
        expect(roots, isNotEmpty);

        final root = roots.first;
        expect(root.name, 'package:foo');
        expect(root.scriptRef, isNull);
        expect(root.children, hasLength(1));
        final child = root.children.first;
        expect(child.name, 'foo.dart');
        expect(child.scriptRef, isNotNull);
        expect(child.children, isEmpty);
      });

      test('four items in two root nodes', () {
        final roots = FileNode.createRootsFrom([ref1, ref2, ref3, ref4]);
        expect(roots, isNotEmpty);
        expect(roots, hasLength(2));

        // roots
        expect(roots[0].name, 'package:foo');
        expect(roots[0].scriptRef, isNotNull);
        expect(roots[1].name, 'package:bar');
        expect(roots[1].scriptRef, isNull);

        // children
        expect(roots[0].children[0].name, 'foo.dart');
        expect(roots[0].children[0].scriptRef, isNotNull);
        expect(roots[1].children[0].name, 'bar.dart');
        expect(roots[1].children[0].scriptRef, isNotNull);
        expect(roots[1].children[1].name, 'baz.dart');
        expect(roots[1].children[1].scriptRef, isNotNull);
      });

      test('handles dotted paths', () {
        final roots = FileNode.createRootsFrom([
          ScriptRef(uri: 'package:foo.bar.baz/qux.dart', id: 'id-5'),
        ]);
        expect(roots, isNotEmpty);
        expect(roots, hasLength(1));

        var child = roots[0];
        expect(child.name, 'package:foo');
        expect(child.scriptRef, isNull);

        child = child.children[0];
        expect(child.name, 'bar/baz/qux.dart');
        expect(child.scriptRef, isNotNull);
      });

      test('handles urls paths', () {
        final roots = FileNode.createRootsFrom([
          ScriptRef(uri: 'google3:///foo/bar/baz.dart', id: 'id-6'),
        ]);
        expect(roots, isNotEmpty);
        expect(roots, hasLength(1));

        var child = roots[0];
        expect(child.name, 'google3:foo');
        expect(child.scriptRef, isNull);

        child = child.children[0];
        expect(child.name, 'bar/baz.dart');
        expect(child.scriptRef, isNotNull);
      });
    });

    group('ScriptRefUtils', () {
      test('splitDirectoryParts', () {
        expect(
          ScriptRefUtils.splitDirectoryParts(ref1),
          orderedEquals(['package:foo']),
        );
        expect(
          ScriptRefUtils.splitDirectoryParts(ref2),
          orderedEquals(['package:foo', 'foo.dart']),
        );
        expect(
          ScriptRefUtils.splitDirectoryParts(
            ScriptRef(uri: 'package:foo.bar.baz/qux.dart', id: 'id-5'),
          ),
          orderedEquals(['package:foo', 'bar/baz/qux.dart']),
        );
        expect(
          ScriptRefUtils.splitDirectoryParts(
            ScriptRef(uri: 'google3:///foo/bar/baz.dart', id: 'id-6'),
          ),
          orderedEquals(['google3:foo', 'bar/baz.dart']),
        );
      });
    });
  });
}

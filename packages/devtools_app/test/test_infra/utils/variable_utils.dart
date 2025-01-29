// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/diagnostics/dart_object_node.dart';
import 'package:devtools_app/src/shared/diagnostics/generic_instance_reference.dart';

import 'package:vm_service/vm_service.dart';

import '../../screens/debugger/typed_data_variable_test.dart';

void resetRef() {
  _refNumber = 0;
}

void resetRoot() {
  _rootNumber = 0;
}

DartObjectNode buildParentListVariable({int length = 2}) {
  return DartObjectNode.create(
    BoundVariable(
      name: _incrementRoot(),
      value: _buildInstanceRefForList(length: length),
    ),
    _isolateRef,
  );
}

DartObjectNode buildListVariable({int length = 2}) {
  final listVariable = buildParentListVariable(length: length);

  for (int i = 0; i < length; i++) {
    listVariable.addChild(
      DartObjectNode.create(
        BoundVariable(
          name: '$i',
          value: InstanceRef(
            id: _incrementRef(),
            kind: InstanceKind.kInt,
            classRef: ClassRef(
              name: 'Integer',
              id: _incrementRef(),
              library: _libraryRef,
            ),
            valueAsString: '$i',
            valueAsStringIsTruncated: false,
          ),
        ),
        _isolateRef,
      ),
    );
  }

  return listVariable;
}

DartObjectNode buildListGroupingVariable({
  required int length,
  required int offset,
  required int count,
}) {
  return DartObjectNode.grouping(
    GenericInstanceRef(
      isolateRef: isolateRef,
      value: _buildInstanceRefForList(length: length),
    ),
    offset: offset,
    count: count,
  );
}

DartObjectNode buildParentMapVariable({int length = 2}) {
  return DartObjectNode.create(
    BoundVariable(
      name: _incrementRoot(),
      value: _buildInstanceRefForMap(length: length),
    ),
    _isolateRef,
  );
}

DartObjectNode buildMapVariable({int length = 2}) {
  final mapVariable = buildParentMapVariable(length: length);

  for (int i = 0; i < length; i++) {
    mapVariable.addChild(
      DartObjectNode.create(
        BoundVariable(
          name: "['key${i + 1}']",
          value: InstanceRef(
            id: _incrementRef(),
            kind: InstanceKind.kDouble,
            classRef: ClassRef(
              name: 'Double',
              id: _incrementRef(),
              library: _libraryRef,
            ),
            valueAsString: '${i + 1}.0',
            valueAsStringIsTruncated: false,
          ),
        ),
        _isolateRef,
      ),
    );
  }

  return mapVariable;
}

DartObjectNode buildMapGroupingVariable({
  required int length,
  required int offset,
  required int count,
}) {
  return DartObjectNode.grouping(
    GenericInstanceRef(
      isolateRef: isolateRef,
      value: _buildInstanceRefForMap(length: length),
    ),
    offset: offset,
    count: count,
  );
}

DartObjectNode buildParentSetVariable({int length = 2}) {
  return DartObjectNode.create(
    BoundVariable(
      name: _incrementRoot(),
      value: _buildInstanceRefForSet(length: length),
    ),
    _isolateRef,
  );
}

DartObjectNode buildSetVariable({int length = 2}) {
  final setVariable = buildParentSetVariable(length: length);

  for (int i = 0; i < length; i++) {
    setVariable.addChild(
      DartObjectNode.fromValue(
        value: InstanceRef(
          id: _incrementRef(),
          kind: InstanceKind.kString,
          classRef: ClassRef(
            name: 'String',
            id: _incrementRef(),
            library: _libraryRef,
          ),
          valueAsString: 'set value $i',
          valueAsStringIsTruncated: false,
        ),
        isolateRef: _isolateRef,
      ),
    );
  }

  return setVariable;
}

DartObjectNode buildSetGroupingVariable({
  required int length,
  required int offset,
  required int count,
}) {
  return DartObjectNode.grouping(
    GenericInstanceRef(
      isolateRef: isolateRef,
      value: _buildInstanceRefForSet(length: length),
    ),
    offset: offset,
    count: count,
  );
}

DartObjectNode buildStringVariable(String value) {
  return DartObjectNode.create(
    BoundVariable(
      name: _incrementRoot(),
      value: InstanceRef(
        id: _incrementRef(),
        kind: InstanceKind.kString,
        classRef: ClassRef(
          name: 'String',
          id: _incrementRef(),
          library: _libraryRef,
        ),
        valueAsString: value,
        valueAsStringIsTruncated: true,
      ),
    ),
    _isolateRef,
  );
}

DartObjectNode buildBooleanVariable(bool value) {
  return DartObjectNode.create(
    BoundVariable(
      name: _incrementRoot(),
      value: InstanceRef(
        id: _incrementRef(),
        kind: InstanceKind.kBool,
        classRef: ClassRef(
          name: 'Boolean',
          id: _incrementRef(),
          library: _libraryRef,
        ),
        valueAsString: '$value',
        valueAsStringIsTruncated: false,
      ),
    ),
    _isolateRef,
  );
}

InstanceRef _buildInstanceRefForMap({required int length}) => InstanceRef(
  id: _incrementRef(),
  kind: InstanceKind.kMap,
  classRef: ClassRef(
    name: '_InternalLinkedHashmap',
    id: _incrementRef(),
    library: _libraryRef,
  ),
  length: length,
);

InstanceRef _buildInstanceRefForList({required int length}) => InstanceRef(
  id: _incrementRef(),
  kind: InstanceKind.kList,
  classRef: ClassRef(
    name: '_GrowableList',
    id: _incrementRef(),
    library: _libraryRef,
  ),
  length: length,
);

InstanceRef _buildInstanceRefForSet({required int length}) => InstanceRef(
  id: _incrementRef(),
  kind: InstanceKind.kSet,
  classRef: ClassRef(name: '_Set', id: _incrementRef(), library: _libraryRef),
  length: length,
);

final _libraryRef = LibraryRef(
  name: 'some library',
  uri: 'package:foo/foo.dart',
  id: 'lib-id-1',
);

final _isolateRef = IsolateRef(
  id: '433',
  number: '1',
  name: 'my-isolate',
  isSystemIsolate: false,
);

int _refNumber = 0;

String _incrementRef() {
  _refNumber++;
  return 'ref$_refNumber';
}

int _rootNumber = 0;

String _incrementRoot() {
  _rootNumber++;
  return 'Root $_rootNumber';
}

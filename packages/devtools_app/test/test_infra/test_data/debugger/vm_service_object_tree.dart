// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:vm_service/vm_service.dart';

final testLib = Library(
  id: testLibRef.id!,
  uri: testLibRef.uri!,
  name: testLibRef.name!,
  dependencies: <LibraryDependency>[],
  classes: [testClass],
  scripts: [testScript],
  variables: [],
  functions: [],
);

final testLibRef = LibraryRef(
  name: 'fooLib',
  uri: 'fooScript.dart',
  id: '1234',
);

final testClassRef = ClassRef(
  id: '1234',
  name: 'FooClass',
  library: testLibRef,
  location: SourceLocation(script: testScript, tokenPos: 10, line: 10),
);

final testClass = Class(
  name: testClassRef.name,
  library: testClassRef.library,
  isAbstract: false,
  isConst: false,
  traceAllocations: false,
  superClass: testSuperClass,
  superType: testSuperType,
  fields: [testField],
  functions: [testFunction],
  id: '1234',
  location: testClassRef.location,
);

// We need to invoke `Script.parse` to build the internal token position table.
final testScript =
    Script.parse(
      Script(
        uri: 'fooScript.dart',
        library: testLibRef,
        id: '1234',
        tokenPosTable: [
          [10, 10, 1],
          [20, 20, 1],
          [30, 30, 1],
        ],
      ).toJson(),
    )!;

final testFunction = Func(
  name: 'fooFunction',
  owner: testClassRef,
  isStatic: false,
  isConst: false,
  implicit: false,
  location: SourceLocation(script: testScript, tokenPos: 20, line: 20),
  signature: InstanceRef(id: '1234'),
  id: '1234',
);

final testField = Field(
  name: 'fooField',
  location: SourceLocation(script: testScript, tokenPos: 30, line: 30),
  declaredType: InstanceRef(id: '1234'),
  owner: testClassRef,
  isStatic: false,
  isConst: false,
  isFinal: false,
  id: '1234',
);

final testSuperClass = ClassRef(
  name: 'fooSuperClass',
  library: testLibRef,
  id: '1234',
);

final testSuperType = InstanceRef(kind: '', id: '1234', name: 'fooSuperType');

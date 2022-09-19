// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
  location: SourceLocation(
    script: testScript,
    tokenPos: 0,
  ),
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

final testScript = Script(
  uri: 'fooScript.dart',
  library: testLibRef,
  id: '1234',
);

final testFunction = Func(
  name: 'fooFunction',
  owner: testClassRef,
  isStatic: false,
  isConst: false,
  implicit: false,
  location: SourceLocation(script: testScript),
  signature: InstanceRef(id: '1234'),
  id: '1234',
);

final testField = Field(
  name: 'fooField',
  location: SourceLocation(script: testScript),
  declaredType: InstanceRef(id: '1234'),
  owner: testClassRef,
  isStatic: false,
  isConst: false,
  isFinal: false,
  id: '1234',
);

final testInstance = Instance(
  id: '1234',
  name: 'fooInstance',
);

final testSuperClass = ClassRef(
  name: 'fooSuperClass',
  library: testLibRef,
  id: '1234',
);

final testSuperType = InstanceRef(
  kind: '',
  id: '1234',
  name: 'fooSuperType',
);

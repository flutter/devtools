// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/object_tree.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  late FakeServiceManager fakeServiceManager;
  late MockDebuggerController debuggerController;
  late MockScriptManager scriptManager;

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    scriptManager = MockScriptManager();
    when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, scriptManager);
    fakeServiceManager.consoleService.ensureServiceInitialized();
    when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));
    debuggerController = createMockDebuggerControllerWithDefaults();

    _resetRef();
    _resetRoot();
  });

  Future<void> pumpDebuggerScreen(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const DebuggerScreenBody(),
        debugger: controller,
      ),
    );
  }

  testWidgetsWithWindowSize('Variables shows items', const Size(1000.0, 4000.0),
      (WidgetTester tester) async {
    when(debuggerController.variables).thenReturn(
      ValueNotifier(
        [
          _buildListVariable(),
          _buildMapVariable(),
          _buildStringVariable('test str'),
          _buildBooleanVariable(true),
        ],
      ),
    );
    await pumpDebuggerScreen(tester, debuggerController);
    expect(find.text('Variables'), findsOneWidget);

    final listFinder = find.selectableText('Root 1: _GrowableList (2 items)');

    // expect a tooltip for the list value
    expect(
      find.byTooltip('_GrowableList (2 items)'),
      findsOneWidget,
    );

    final mapFinder = find.selectableTextContaining(
      'Root 2: _InternalLinkedHashmap (2 items)',
    );
    final mapElement1Finder = find.selectableTextContaining("['key1']: 1.0");
    final mapElement2Finder = find.selectableTextContaining("['key2']: 2.0");

    expect(listFinder, findsOneWidget);
    expect(mapFinder, findsOneWidget);
    expect(
      find.selectableTextContaining("Root 3: 'test str...'"),
      findsOneWidget,
    );
    expect(
      find.selectableTextContaining('Root 4: true'),
      findsOneWidget,
    );

    // Initially list is not expanded.
    expect(find.selectableTextContaining('0: 3'), findsNothing);
    expect(find.selectableTextContaining('1: 4'), findsNothing);

    // Expand list.
    await tester.tap(listFinder);
    await tester.pump();
    expect(find.selectableTextContaining('0: 0'), findsOneWidget);
    expect(find.selectableTextContaining('1: 1'), findsOneWidget);

    // Initially map is not expanded.
    expect(mapElement1Finder, findsNothing);
    expect(mapElement2Finder, findsNothing);

    // Expand map.
    await tester.tap(mapFinder);
    await tester.pump();
    expect(mapElement1Finder, findsOneWidget);
    expect(mapElement2Finder, findsOneWidget);
  });

  testWidgetsWithWindowSize('Children in large list variables are grouped',
      const Size(1000.0, 4000.0), (WidgetTester tester) async {
    final list = _buildParentListVariable(length: 380250);
    await buildVariablesTree(list);
    when(debuggerController.variables).thenReturn(
      ValueNotifier(
        [
          list,
        ],
      ),
    );
    await pumpDebuggerScreen(tester, debuggerController);

    final listFinder =
        find.selectableText('Root 1: _GrowableList (380,250 items)');
    final group0To9999Finder = find.selectableTextContaining('[0 - 9999]');
    final group10000To19999Finder =
        find.selectableTextContaining('[10000 - 19999]');
    final group370000To379999Finder =
        find.selectableTextContaining('[370000 - 379999]');
    final group380000To380249Finder =
        find.selectableTextContaining('[380000 - 380249]');

    final group370000To370099Finder =
        find.selectableTextContaining('[370000 - 370099]');
    final group370100To370199Finder =
        find.selectableTextContaining('[370100 - 370199]');
    final group370200To370299Finder =
        find.selectableTextContaining('[370200 - 370299]');

    // Initially list is not expanded.
    expect(listFinder, findsOneWidget);
    expect(group0To9999Finder, findsNothing);
    expect(group10000To19999Finder, findsNothing);
    expect(group370000To379999Finder, findsNothing);
    expect(group380000To380249Finder, findsNothing);

    // Expand list.
    await tester.tap(listFinder);
    await tester.pump();
    expect(group0To9999Finder, findsOneWidget);
    expect(group10000To19999Finder, findsOneWidget);
    expect(group370000To379999Finder, findsOneWidget);
    expect(group380000To380249Finder, findsOneWidget);

    // Initially group [370000 - 379999] is not expanded.
    expect(group370000To370099Finder, findsNothing);
    expect(group370100To370199Finder, findsNothing);
    expect(group370200To370299Finder, findsNothing);

    // Expand group [370000 - 379999].
    await tester.tap(group370000To379999Finder);
    await tester.pump();
    expect(group370000To370099Finder, findsOneWidget);
    expect(group370100To370199Finder, findsOneWidget);
    expect(group370200To370299Finder, findsOneWidget);
  });

  testWidgetsWithWindowSize(
      'Children in large map variables are grouped', const Size(1000.0, 4000.0),
      (WidgetTester tester) async {
    final map = _buildParentMapVariable(length: 243621);
    await buildVariablesTree(map);
    when(debuggerController.variables).thenReturn(
      ValueNotifier(
        [
          map,
        ],
      ),
    );
    await pumpDebuggerScreen(tester, debuggerController);

    final listFinder =
        find.selectableText('Root 1: _InternalLinkedHashmap (243,621 items)');
    final group0To9999Finder = find.selectableTextContaining('[0 - 9999]');
    final group10000To19999Finder =
        find.selectableTextContaining('[10000 - 19999]');
    final group230000To239999Finder =
        find.selectableTextContaining('[230000 - 239999]');
    final group240000To243620Finder =
        find.selectableTextContaining('[240000 - 243620]');

    final group0To99Finder = find.selectableTextContaining('[0 - 99]');
    final group100To199Finder = find.selectableTextContaining('[100 - 199]');
    final group200To299Finder = find.selectableTextContaining('[200 - 299]');

    // Initially map is not expanded.
    expect(listFinder, findsOneWidget);
    expect(group0To9999Finder, findsNothing);
    expect(group10000To19999Finder, findsNothing);
    expect(group230000To239999Finder, findsNothing);
    expect(group240000To243620Finder, findsNothing);

    // Expand map.
    await tester.tap(listFinder);
    await tester.pump();
    expect(group0To9999Finder, findsOneWidget);
    expect(group10000To19999Finder, findsOneWidget);
    expect(group230000To239999Finder, findsOneWidget);
    expect(group240000To243620Finder, findsOneWidget);

    // Initially group [0 - 9999] is not expanded.
    expect(group0To99Finder, findsNothing);
    expect(group100To199Finder, findsNothing);
    expect(group200To299Finder, findsNothing);

    // Expand group [0 - 9999].
    await tester.tap(group0To9999Finder);
    await tester.pump();
    expect(group0To99Finder, findsOneWidget);
    expect(group100To199Finder, findsOneWidget);
    expect(group200To299Finder, findsOneWidget);
  });
}

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

void _resetRef() {
  _refNumber = 0;
}

int _rootNumber = 0;

String _incrementRoot() {
  _rootNumber++;
  return 'Root $_rootNumber';
}

void _resetRoot() {
  _rootNumber = 0;
}

DartObjectNode _buildParentListVariable({int length = 2}) {
  return DartObjectNode.create(
    BoundVariable(
      name: _incrementRoot(),
      value: InstanceRef(
        id: _incrementRef(),
        kind: InstanceKind.kList,
        classRef: ClassRef(
          name: '_GrowableList',
          id: _incrementRef(),
          library: _libraryRef,
        ),
        length: length,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    _isolateRef,
  );
}

DartObjectNode _buildListVariable({int length = 2}) {
  final listVariable = _buildParentListVariable(length: length);

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
            identityHashCode: null,
          ),
          declarationTokenPos: null,
          scopeEndTokenPos: null,
          scopeStartTokenPos: null,
        ),
        _isolateRef,
      ),
    );
  }

  return listVariable;
}

DartObjectNode _buildParentMapVariable({int length = 2}) {
  return DartObjectNode.create(
    BoundVariable(
      name: _incrementRoot(),
      value: InstanceRef(
        id: _incrementRef(),
        kind: InstanceKind.kMap,
        classRef: ClassRef(
          name: '_InternalLinkedHashmap',
          id: _incrementRef(),
          library: _libraryRef,
        ),
        length: length,
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    _isolateRef,
  );
}

DartObjectNode _buildMapVariable({int length = 2}) {
  final mapVariable = _buildParentMapVariable(length: length);

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
            identityHashCode: null,
          ),
          declarationTokenPos: null,
          scopeEndTokenPos: null,
          scopeStartTokenPos: null,
        ),
        _isolateRef,
      ),
    );
  }

  return mapVariable;
}

DartObjectNode _buildStringVariable(String value) {
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
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    _isolateRef,
  );
}

DartObjectNode _buildBooleanVariable(bool value) {
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
        identityHashCode: null,
      ),
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ),
    _isolateRef,
  );
}

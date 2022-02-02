// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')

import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/src/debugger/console.dart';
import 'package:devtools_app/src/debugger/debugger_controller.dart';
// import 'package:devtools_app/src/debugger/debugger_model.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/service_manager.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
// import 'package:vm_service/vm_service.dart';

void main() {
  group('DebuggerScreen', () {
    FakeServiceManager fakeServiceManager;
    MockDebuggerController debuggerController;

    const windowSize = Size(4000.0, 4000.0);

    Future<void> pumpConsole(
      WidgetTester tester,
      DebuggerController controller,
    ) async {
      await tester.pumpWidget(wrapWithControllers(
        Row(
          children: [
            Flexible(child: DebuggerConsole.buildHeader()),
            const Expanded(child: DebuggerConsole()),
          ],
        ),
        debugger: controller,
      ));
    }

    setUp(() {
      fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      fakeServiceManager.consoleService.ensureServiceInitialized();

      when(fakeServiceManager.errorBadgeManager.errorCountNotifier(any))
          .thenReturn(ValueNotifier<int>(0));

      debuggerController = MockDebuggerController.withDefaults();
    });

    testWidgetsWithWindowSize(
        'Console area shows processed ansi text', windowSize,
        (WidgetTester tester) async {
      serviceManager.consoleService.appendStdio(_ansiCodesOutput());

      await pumpConsole(tester, debuggerController);

      final finder =
          find.selectableText('Ansi color codes processed for console');
      expect(finder, findsOneWidget);
      finder.evaluate().forEach((element) {
        final selectableText = element.widget as SelectableText;
        final textSpan = selectableText.textSpan;
        final secondSpan = textSpan.children[1] as TextSpan;
        expect(
          secondSpan.text,
          'console',
          reason: 'Text with ansi code should be in separate span',
        );
        expect(
          secondSpan.style.backgroundColor,
          const Color.fromRGBO(215, 95, 135, 1),
        );
      });
    });
  });
}

// Widget getWidgetFromFinder(Finder finder) {
//   return finder.first.evaluate().first.widget;
// }

String _ansiCodesOutput() {
  final sb = StringBuffer();
  sb.write('Ansi color codes processed for ');
  final pen = AnsiPen()..rgb(r: 0.8, g: 0.3, b: 0.4, bg: true);
  sb.write(pen('console'));
  return sb.toString();
}

// final libraryRef = LibraryRef(
//   name: 'some library',
//   uri: 'package:foo/foo.dart',
//   id: 'lib-id-1',
// );

// final isolateRef = IsolateRef(
//   id: '433',
//   number: '1',
//   name: 'my-isolate',
//   isSystemIsolate: false,
// );

// int refNumber = 0;

// String incrementRef() {
//   refNumber++;
//   return 'ref$refNumber';
// }

// void resetRef() {
//   refNumber = 0;
// }

// int rootNumber = 0;

// String incrementRoot() {
//   rootNumber++;
//   return 'Root $rootNumber';
// }

// void resetRoot() {
//   rootNumber = 0;
// }

// DartObjectNode buildParentListVariable({int length = 2}) {
//   return DartObjectNode.create(
//     BoundVariable(
//       name: incrementRoot(),
//       value: InstanceRef(
//         id: incrementRef(),
//         kind: InstanceKind.kList,
//         classRef: ClassRef(
//           name: '_GrowableList',
//           id: incrementRef(),
//           library: libraryRef,
//         ),
//         length: length,
//         identityHashCode: null,
//       ),
//       declarationTokenPos: null,
//       scopeEndTokenPos: null,
//       scopeStartTokenPos: null,
//     ),
//     isolateRef,
//   );
// }

// DartObjectNode buildListVariable({int length = 2}) {
//   final listVariable = buildParentListVariable(length: length);

//   for (int i = 0; i < length; i++) {
//     listVariable.addChild(
//       DartObjectNode.create(
//         BoundVariable(
//           name: '$i',
//           value: InstanceRef(
//             id: incrementRef(),
//             kind: InstanceKind.kInt,
//             classRef: ClassRef(
//                 name: 'Integer', id: incrementRef(), library: libraryRef),
//             valueAsString: '$i',
//             valueAsStringIsTruncated: false,
//             identityHashCode: null,
//           ),
//           declarationTokenPos: null,
//           scopeEndTokenPos: null,
//           scopeStartTokenPos: null,
//         ),
//         isolateRef,
//       ),
//     );
//   }

//   return listVariable;
// }

// DartObjectNode buildParentMapVariable({int length = 2}) {
//   return DartObjectNode.create(
//     BoundVariable(
//       name: incrementRoot(),
//       value: InstanceRef(
//         id: incrementRef(),
//         kind: InstanceKind.kMap,
//         classRef: ClassRef(
//             name: '_InternalLinkedHashmap',
//             id: incrementRef(),
//             library: libraryRef),
//         length: length,
//         identityHashCode: null,
//       ),
//       declarationTokenPos: null,
//       scopeEndTokenPos: null,
//       scopeStartTokenPos: null,
//     ),
//     isolateRef,
//   );
// }

// DartObjectNode buildMapVariable({int length = 2}) {
//   final mapVariable = buildParentMapVariable(length: length);

//   for (int i = 0; i < length; i++) {
//     mapVariable.addChild(
//       DartObjectNode.create(
//         BoundVariable(
//           name: "['key${i + 1}']",
//           value: InstanceRef(
//             id: incrementRef(),
//             kind: InstanceKind.kDouble,
//             classRef: ClassRef(
//                 name: 'Double', id: incrementRef(), library: libraryRef),
//             valueAsString: '${i + 1}.0',
//             valueAsStringIsTruncated: false,
//             identityHashCode: null,
//           ),
//           declarationTokenPos: null,
//           scopeEndTokenPos: null,
//           scopeStartTokenPos: null,
//         ),
//         isolateRef,
//       ),
//     );
//   }

//   return mapVariable;
// }

// DartObjectNode buildStringVariable(String value) {
//   return DartObjectNode.create(
//     BoundVariable(
//       name: incrementRoot(),
//       value: InstanceRef(
//         id: incrementRef(),
//         kind: InstanceKind.kString,
//         classRef: ClassRef(
//           name: 'String',
//           id: incrementRef(),
//           library: libraryRef,
//         ),
//         valueAsString: value,
//         valueAsStringIsTruncated: true,
//         identityHashCode: null,
//       ),
//       declarationTokenPos: null,
//       scopeEndTokenPos: null,
//       scopeStartTokenPos: null,
//     ),
//     isolateRef,
//   );
// }

// DartObjectNode buildBooleanVariable(bool value) {
//   return DartObjectNode.create(
//     BoundVariable(
//       name: incrementRoot(),
//       value: InstanceRef(
//         id: incrementRef(),
//         kind: InstanceKind.kBool,
//         classRef: ClassRef(
//           name: 'Boolean',
//           id: incrementRef(),
//           library: libraryRef,
//         ),
//         valueAsString: '$value',
//         valueAsStringIsTruncated: false,
//         identityHashCode: null,
//       ),
//       declarationTokenPos: null,
//       scopeEndTokenPos: null,
//       scopeStartTokenPos: null,
//     ),
//     isolateRef,
//   );
// }

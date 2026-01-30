// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:dart_service_protocol_shared/dart_service_protocol_shared.dart';
import 'package:devtools_app/src/shared/editor/api_classes.dart';
import 'package:devtools_app/src/shared/editor/editor_client.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockDTDManager mockDTDManager;
  late MockDartToolingDaemon mockDtd;
  late EditorClient editorClient;

  final methodToResponseJson = <LspMethod, String>{
    LspMethod.codeAction: _codeActionResponseJson,
    LspMethod.editableArguments: _editableArgumentsResponseJson,
    LspMethod.editArgument: 'null',
    LspMethod.executeCommand: 'null',
  };

  setUp(() {
    mockDTDManager = MockDTDManager();
    mockDtd = MockDartToolingDaemon();
    when(mockDTDManager.connection).thenReturn(ValueNotifier(mockDtd));

    for (final MapEntry(key: method, value: responseJson)
        in methodToResponseJson.entries) {
      when(
        mockDtd.call(
          lspServiceName,
          method.methodName,
          params: anyNamed('params'),
        ),
      ).thenAnswer((_) async => _createDtdResponse(responseJson));
    }

    for (final method in LspMethod.values) {
      method.isRegistered = true;
    }

    editorClient = EditorClient(mockDTDManager);
  });

  group('getRefactors', () {
    test('deserializes refactors from the CodeActionResult', () async {
      final result = await editorClient.getRefactors(
        textDocument: _textDocument,
        range: _editorRange,
        screenId: _fakeScreenId,
      );

      // Verify the expected request was sent.
      verify(
        mockDtd.call(
          lspServiceName,
          LspMethod.codeAction.methodName,
          params: json.decode(_codeActionRequestJson),
        ),
      ).called(1);

      // Verify deserialization of the response succeeded.
      expect(result, isA<CodeActionResult>());
      const expectedRefactors = [
        'Wrap with widget...',
        'Wrap with Center',
        'Wrap with Container',
        'Wrap with Expanded',
        'Wrap with Flexible',
        'Wrap with Padding',
        'Wrap with SizedBox',
        'Wrap with Column',
        'Wrap with Row',
        'Wrap with Builder',
        'Wrap with ValueListenableBuilder',
        'Wrap with StreamBuilder',
        'Wrap with FutureBuilder',
      ];
      expect(
        result!.actions.map((a) => a.title),
        containsAll(expectedRefactors),
      );
    });

    test('returns null when API is unavailable', () async {
      LspMethod.codeAction.isRegistered = false;

      final result = await editorClient.getRefactors(
        textDocument: _textDocument,
        range: _editorRange,
        screenId: _fakeScreenId,
      );

      // Verify that the request was never sent.
      verifyNever(mockDtd.call(any, any, params: anyNamed('params')));

      // Verify the response is null.
      expect(result, isNull);
    });
  });

  group('editableArguments', () {
    test('deserializes arguments from the EditableArgumentsResult', () async {
      final result = await editorClient.getEditableArguments(
        textDocument: _textDocument,
        position: _cursorPosition,
        screenId: _fakeScreenId,
      );

      // Verify the expected request was sent.
      verify(
        mockDtd.call(
          lspServiceName,
          LspMethod.editableArguments.methodName,
          params: json.decode(_editableArgumentsRequestJson),
        ),
      ).called(1);

      // Verify deserialization of the response succeeded.
      final expectedArgs = [
        'mainAxisAlignment - MainAxisAlignment.end',
        'mainAxisSize - null',
        'crossAxisAlignment - null',
        'textDirection - null',
        'verticalDirection - null',
        'textBaseline - null',
        'spacing - null',
      ];

      expect(
        result!.args.map((arg) => '${arg.name} - ${arg.value}'),
        containsAll(expectedArgs),
      );
    });

    test('returns null when API is not available', () async {
      LspMethod.editableArguments.isRegistered = false;

      final result = await editorClient.getEditableArguments(
        textDocument: _textDocument,
        position: _cursorPosition,
        screenId: _fakeScreenId,
      );

      // Verify that the request was never sent.
      verifyNever(mockDtd.call(any, any, params: anyNamed('params')));

      // Verify the response is null.
      expect(result, isNull);
    });
  });

  group('executeCommand', () {
    test('sends an executeCommand request', () async {
      final result = await editorClient.executeCommand(
        commandName: 'dart.edit.codeAction.apply',
        commandArgs: [json.decode(_executeCommandArg) as Map<String, Object?>],
        screenId: _fakeScreenId,
      );

      // Verify the expected request was sent.
      verify(
        mockDtd.call(
          lspServiceName,
          LspMethod.executeCommand.methodName,
          params: json.decode(_executeCommandRequestJson),
        ),
      ).called(1);

      // Verify the response was successful.
      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('returns failure response when API is not available', () async {
      LspMethod.executeCommand.isRegistered = false;

      final result = await editorClient.executeCommand(
        commandName: 'dart.edit.codeAction.apply',
        commandArgs: [json.decode(_executeCommandArg) as Map<String, Object?>],
        screenId: _fakeScreenId,
      );

      // Verify the request was never sent.
      verifyNever(mockDtd.call(any, any, params: anyNamed('params')));

      // Verify the failure response.
      expect(result.success, isFalse);
      expect(result.errorMessage, 'API is unavailable.');
    });
  });

  group('editArgument', () {
    test('sends an editArgument request', () async {
      final result = await editorClient.editArgument(
        textDocument: _textDocument,
        position: _cursorPosition,
        name: 'mainAxisAlignment',
        value: 'MainAxisAlignment.center',
        screenId: _fakeScreenId,
      );

      // Verify the expected request was sent.
      verify(
        mockDtd.call(
          lspServiceName,
          LspMethod.editArgument.methodName,
          params: json.decode(_editArgumentRequestJson),
        ),
      ).called(1);

      // Verify the response is successful.
      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('returns failure response when API is not available', () async {
      LspMethod.editArgument.isRegistered = false;

      final result = await editorClient.editArgument(
        textDocument: _textDocument,
        position: _cursorPosition,
        name: 'mainAxisAlignment',
        value: 'MainAxisAlignment.center',
        screenId: _fakeScreenId,
      );

      // Verify that the request was never sent.
      verifyNever(mockDtd.call(any, any, params: anyNamed('params')));

      // Verify the failure response.
      expect(result.success, isFalse);
      expect(result.errorMessage, 'API is unavailable.');
    });
  });

  group('initialization', () {
    test('checks for existing services registered on DTD', () async {
      // Add getDevices service to registered services.
      final getDevicesService = ClientServiceInfo(editorServiceName, {
        EditorMethod.getDevices.name: ClientServiceMethodInfo(
          EditorMethod.getDevices.name,
        ),
      });
      final response = RegisteredServicesResponse(
        dtdServices: [],
        clientServices: [getDevicesService],
      );
      when(mockDtd.getRegisteredServices()).thenAnswer((_) async => response);

      // Initialize the client.
      final client = EditorClient(mockDTDManager);
      await client.initialized;

      // Check that it supports getDevices.
      expect(client.supportsGetDevices, isTrue);
    });
  });
}

const _fakeScreenId = 'DevToolsScreen';
const _documentUri = 'file:///Users/me/flutter_app/lib/main.dart';
const _documentVersion = 1;
const _cursorLine = 10;
const _cursorChar = 20;

final _textDocument = TextDocument(
  uriAsString: _documentUri,
  version: _documentVersion,
);
final _cursorPosition = CursorPosition(
  line: _cursorLine,
  character: _cursorChar,
);
final _editorRange = EditorRange(start: _cursorPosition, end: _cursorPosition);

DTDResponse _createDtdResponse(String jsonStr) {
  final result = json.decode(_wrapJsonInResult(jsonStr));
  return DTDResponse('1', 'type', result);
}

String _wrapJsonInResult(String jsonStr) => '{"result": $jsonStr}';

const _editArgumentRequestJson =
    '''
{
  "textDocument": {
    "uri": "$_documentUri",
    "version": $_documentVersion
  },
  "position": {
    "character": $_cursorChar,
    "line": $_cursorLine
  },
  "edit": {
    "name": "mainAxisAlignment",
    "newValue": "MainAxisAlignment.center"
  },
  "type": "Object"
}
''';

const _executeCommandArg =
    '''
    {
      "textDocument": {
        "uri": "$_documentUri",
        "version": $_documentVersion
      },
      "range": {
        "end": {
          "character": $_cursorChar,
          "line": $_cursorLine
        },
        "start": {
          "character": $_cursorChar,
          "line": $_cursorLine
        }
      },
      "kind": "refactor.flutter.wrap.futureBuilder",
      "loggedAction": "dart.assist.flutter.wrap.futureBuilder"
    }
''';

const _executeCommandRequestJson =
    '''
{
  "command": "dart.edit.codeAction.apply",
  "arguments": [
    $_executeCommandArg
  ],
  "type": "Object"
}
''';

const _editableArgumentsRequestJson =
    '''
{
  "textDocument": {
    "uri": "$_documentUri",
    "version": $_documentVersion
  },
  "position": {
    "character": $_cursorChar,
    "line": $_cursorLine
  },
  "type": "Object"
}
''';

const _codeActionRequestJson =
    '''
{
  "textDocument": {
    "uri": "$_documentUri",
    "version": $_documentVersion
  },
  "range": {
    "start": {
      "character": $_cursorChar,
      "line": $_cursorLine
    },
    "end": {
      "character": $_cursorChar,
      "line": $_cursorLine
    }
  },
  "context": {
    "diagnostics": [],
    "only": [
      "refactor.flutter.wrap"
    ]
  },
  "type": "Object"
}
''';

const _editableArgumentsResponseJson =
    '''
{
  "arguments": [
    {
      "defaultValue": "MainAxisAlignment.start",
      "documentation": "Creates a vertical array of children.",
      "hasArgument": true,
      "isDeprecated": false,
      "isEditable": true,
      "isNullable": false,
      "isRequired": false,
      "name": "mainAxisAlignment",
      "options": [
        "MainAxisAlignment.start",
        "MainAxisAlignment.end",
        "MainAxisAlignment.center",
        "MainAxisAlignment.spaceBetween",
        "MainAxisAlignment.spaceAround",
        "MainAxisAlignment.spaceEvenly"
      ],
      "type": "enum",
      "value": "MainAxisAlignment.end"
    },
    {
      "defaultValue": "MainAxisSize.max",
      "documentation": "Creates a vertical array of children.",
      "hasArgument": false,
      "isDeprecated": false,
      "isEditable": true,
      "isNullable": false,
      "isRequired": false,
      "name": "mainAxisSize",
      "options": [
        "MainAxisSize.min",
        "MainAxisSize.max"
      ],
      "type": "enum"
    },
    {
      "defaultValue": "CrossAxisAlignment.center",
      "documentation": "Creates a vertical array of children.",
      "hasArgument": false,
      "isDeprecated": false,
      "isEditable": true,
      "isNullable": false,
      "isRequired": false,
      "name": "crossAxisAlignment",
      "options": [
        "CrossAxisAlignment.start",
        "CrossAxisAlignment.end",
        "CrossAxisAlignment.center",
        "CrossAxisAlignment.stretch",
        "CrossAxisAlignment.baseline"
      ],
      "type": "enum"
    },
    {
      "documentation": "Creates a vertical array of children.",
      "hasArgument": false,
      "isDeprecated": false,
      "isEditable": true,
      "isNullable": true,
      "isRequired": false,
      "name": "textDirection",
      "options": [
        "TextDirection.rtl",
        "TextDirection.ltr"
      ],
      "type": "enum"
    },
    {
      "defaultValue": "VerticalDirection.down",
      "documentation": "Creates a vertical array of children.",
      "hasArgument": false,
      "isDeprecated": false,
      "isEditable": true,
      "isNullable": false,
      "isRequired": false,
      "name": "verticalDirection",
      "options": [
        "VerticalDirection.up",
        "VerticalDirection.down"
      ],
      "type": "enum"
    },
    {
      "documentation": "Creates a vertical array of children.",
      "hasArgument": false,
      "isDeprecated": false,
      "isEditable": true,
      "isNullable": true,
      "isRequired": false,
      "name": "textBaseline",
      "options": [
        "TextBaseline.alphabetic",
        "TextBaseline.ideographic"
      ],
      "type": "enum"
    },
    {
      "defaultValue": 0.0,
      "documentation": "Creates a vertical array of children.",
      "hasArgument": false,
      "isDeprecated": false,
      "isEditable": true,
      "isNullable": false,
      "isRequired": false,
      "name": "spacing",
      "type": "double"
    }
  ],
  "documentation": "Creates a vertical array of children.",
  "name": "Column",
  "range": {
    "end": {
      "character": 13,
      "line": 64
    },
    "start": {
      "character": 19,
      "line": 48
    }
  },
  "textDocument": {
    "uri": "$_documentUri",
    "version": $_documentVersion
  }
}
''';

const _codeActionResponseJson =
    '''
[
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.generic",
        "loggedAction": "dart.assist.flutter.wrap.generic"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with widget..."
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.center",
        "loggedAction": "dart.assist.flutter.wrap.center"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with Center"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.container",
        "loggedAction": "dart.assist.flutter.wrap.container"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with Container"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.expanded",
        "loggedAction": "dart.assist.flutter.wrap.expanded"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with Expanded"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.flexible",
        "loggedAction": "dart.assist.flutter.wrap.flexible"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with Flexible"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.padding",
        "loggedAction": "dart.assist.flutter.wrap.padding"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with Padding"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.sizedBox",
        "loggedAction": "dart.assist.flutter.wrap.sizedBox"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with SizedBox"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.column",
        "loggedAction": "dart.assist.flutter.wrap.column"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with Column"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.row",
        "loggedAction": "dart.assist.flutter.wrap.row"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with Row"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.builder",
        "loggedAction": "dart.assist.flutter.wrap.builder"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with Builder"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.valueListenableBuilder",
        "loggedAction": "dart.assist.flutter.wrap.valueListenableBuilder"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with ValueListenableBuilder"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.streamBuilder",
        "loggedAction": "dart.assist.flutter.wrap.streamBuilder"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with StreamBuilder"
  },
  {
    "arguments": [
      {
        "textDocument": {
          "uri": "$_documentUri",
          "version": $_documentVersion
        },
        "range": {
          "end": {
            "character": $_cursorChar,
            "line": $_cursorLine
          },
          "start": {
            "character": $_cursorChar,
            "line": $_cursorLine
          }
        },
        "kind": "refactor.flutter.wrap.futureBuilder",
        "loggedAction": "dart.assist.flutter.wrap.futureBuilder"
      }
    ],
    "command": "dart.edit.codeAction.apply",
    "title": "Wrap with FutureBuilder"
  }
]
''';

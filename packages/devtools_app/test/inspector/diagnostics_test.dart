import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/ui/hover.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosticsNodeDescription', () {
    setUp(() {
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(ServiceConnectionManager, FakeServiceManager());
    });

    group('hover eval', () {
      final renderObjectJson = jsonDecode(
        '''
        {
          "properties": [
            {
              "description": "horizontal",
              "name": "direction"
            },
            {
              "description": "start",
              "name": "mainAxisAlignment"
            },
            {
              "description": "max",
              "name": "mainAxisSize"
            },
            {
              "description": "center",
              "name": "crossAxisAlignment"
            },
            {
              "description": "ltr",
              "name": "textDirection"
            },
            {
              "description": "down",
              "name": "verticalDirection"
            }
          ]
        }
      ''',
      );
      final nodeJson = <String, Object?>{
        'widgetRuntimeType': 'Row',
        'renderObject': renderObjectJson,
        'hasChildren': false,
        'children': [],
      };
      final inspectorService = MockObjectGroupBase();
      final diagnostic = RemoteDiagnosticsNode(
        nodeJson,
        inspectorService,
        false,
        null,
      );
      late DiagnosticsNodeDescription diagnosticsNodeDescription;

      setUp(() {
        preferences.inspector.setHoverEvalMode(true);
        diagnosticsNodeDescription = DiagnosticsNodeDescription(
          diagnostic,
          debuggerController: MockDebuggerController(),
        );
      });

      testWidgets('can be enabled from preferences',
          (WidgetTester tester) async {
        await tester.pumpWidget(wrap(diagnosticsNodeDescription));

        final hoverCardTooltip =
            tester.widget(find.byType(HoverCardTooltip)) as HoverCardTooltip;
        expect(hoverCardTooltip.enabled(), true);
      });

      testWidgets('can be disabled from preferences',
          (WidgetTester tester) async {
        preferences.inspector.setHoverEvalMode(false);

        await tester.pumpWidget(wrap(diagnosticsNodeDescription));

        final hoverCardTooltip =
            tester.widget(find.byType(HoverCardTooltip)) as HoverCardTooltip;
        expect(hoverCardTooltip.enabled(), false);
      });

      testWidgets('disabled when inspector service not set',
          (WidgetTester tester) async {
        final diagnosticWithoutService = RemoteDiagnosticsNode(
          nodeJson,
          null,
          false,
          null,
        );
        diagnosticsNodeDescription = DiagnosticsNodeDescription(
          diagnosticWithoutService,
          debuggerController: MockDebuggerController(),
        );

        await tester.pumpWidget(wrap(diagnosticsNodeDescription));

        final hoverCardTooltip =
            tester.widget(find.byType(HoverCardTooltip)) as HoverCardTooltip;
        expect(hoverCardTooltip.enabled(), false);
      });
    });
  });
}

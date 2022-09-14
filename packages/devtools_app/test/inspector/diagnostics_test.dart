import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/ui/hover.dart';
import 'package:devtools_app/src/ui/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosticsNodeDescription', () {
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
    setUp(() {
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(ServiceConnectionManager, FakeServiceManager());
    });

    group('hover eval', () {
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

    group('approximateNodeWidth', () {
      testWidgets('property diagnostics node with name and description',
          (WidgetTester tester) async {
        final nodeJson = <String, Object?>{
          'widgetRuntimeType': 'Row',
          'renderObject': renderObjectJson,
          'hasChildren': false,
          'children': [],
          'description':
              'this is a showname description, which will show up after the name',
          'showName': true,
          'name': 'THE NAME to be shown',
        };
        final diagnosticWithoutService = RemoteDiagnosticsNode(
          nodeJson,
          null,
          true,
          null,
        );
        final diagnosticsNodeDescription = DiagnosticsNodeDescription(
          diagnosticWithoutService,
          debuggerController: MockDebuggerController(),
        );

        await tester.pumpWidget(wrap(diagnosticsNodeDescription));

        final approximatedWidth =
            DiagnosticsNodeDescription.approximateNodeWidth(
          diagnosticWithoutService,
        );

        final diagnosticsNodeFind = find.byType(DiagnosticsNodeDescription);
        // There are many rich texts, containg the name, and description.
        final allRichTexts = find
            .descendant(
              of: diagnosticsNodeFind,
              matching: find.byType(RichText),
            )
            .evaluate()
            .map((e) => e.widget as RichText);
        final measuredWidthOfAllRichTexts = allRichTexts.fold<double>(
          0,
          (previousValue, richText) =>
              previousValue +
              calculateTextSpanWidth(
                richText.text as TextSpan,
              ),
        );
        expect(
          approximatedWidth,
          moreOrLessEquals(measuredWidthOfAllRichTexts, epsilon: 5.0),
        );
      });

      testWidgets('diagnostics node with icon and description',
          (WidgetTester tester) async {
        final nodeJson = <String, Object?>{
          'widgetRuntimeType': 'Row',
          'renderObject': renderObjectJson,
          'hasChildren': false,
          'description': 'This is the description',
          'children': [],
          'showName': false,
        };
        final diagnosticWithoutService = RemoteDiagnosticsNode(
          nodeJson,
          null,
          false,
          null,
        );
        final diagnosticsNodeDescription = DiagnosticsNodeDescription(
          diagnosticWithoutService,
          debuggerController: MockDebuggerController(),
        );

        await tester.pumpWidget(wrap(diagnosticsNodeDescription));

        final approximatedTextWidth =
            DiagnosticsNodeDescription.approximateNodeWidth(
          diagnosticWithoutService,
        );

        final diagnosticsNodeFind = find.byType(DiagnosticsNodeDescription);
        // The icon is part of the clickable width, so we include it.
        final measuredIconWidth = tester
            .getSize(
              find.descendant(
                of: diagnosticsNodeFind,
                matching: find.byType(AssetImageIcon),
              ),
            )
            .width;

        // There is only one rich text widget, containing the description.
        final richTextWidget = find
            .descendant(
              of: diagnosticsNodeFind,
              matching: find.byType(RichText),
            )
            .first
            .evaluate()
            .first
            .widget as RichText;
        final measuredTextWidth =
            calculateTextSpanWidth(richTextWidget.text as TextSpan);

        expect(
          approximatedTextWidth,
          moreOrLessEquals(
            measuredTextWidth + measuredIconWidth,
            epsilon: 5.0,
          ),
        );
      });

      testWidgets('error node with different fontSize',
          (WidgetTester tester) async {
        final nodeJson = <String, Object?>{
          'widgetRuntimeType': 'Row',
          'renderObject': renderObjectJson,
          'hasChildren': false,
          'children': [],
          'description':
              'this is a showname description, which will show up after the name',
          'showName': true,
          'name': 'THE NAME to be shown',
          'level': 'error',
        };
        final diagnosticWithoutService = RemoteDiagnosticsNode(
          nodeJson,
          null,
          false,
          null,
        );
        const textStyle = TextStyle(fontSize: 24.0, fontFamily: 'Roboto');
        final diagnosticsNodeDescription = DiagnosticsNodeDescription(
          diagnosticWithoutService,
          debuggerController: MockDebuggerController(),
          style: textStyle,
        );

        await tester.pumpWidget(wrap(diagnosticsNodeDescription));

        print('STEP 1:');
        final approximatedWidth =
            DiagnosticsNodeDescription.approximateNodeWidth(
          diagnosticWithoutService,
        );

        final diagnosticsNodeFind = find.byType(DiagnosticsNodeDescription);
        // There are many rich texts, containg the name, and description.
        final allRichTexts = find
            .descendant(
              of: diagnosticsNodeFind,
              matching: find.byType(RichText),
            )
            .evaluate()
            .map((e) => e.widget as RichText);
        print('STEP 2:');
        final allTextSpansFromRichTexts =
            allRichTexts.map((e) => e.text as TextSpan).toList();
        final measuredWidthOfAllRichTexts =
            allRichTexts.fold<double>(0, (previousValue, richText) {
          final originalTextSpan = richText.text as TextSpan;

          return previousValue +
              calculateTextSpanWidth(
                originalTextSpan,
              );
        });
        // double measuredWidthOfAllRichTexts = 0;
        // for (var i = 0; i < allTextSpansFromRichTexts.length; i++) {
        //   final originalTextSpan = allTextSpansFromRichTexts[i];
        //   final textSpan = TextSpan(
        //     text: originalTextSpan.text,
        //     style: textStyle,
        //   );
        //   if (originalTextSpan.children != null) {
        //     allTextSpansFromRichTexts
        //         .addAll(originalTextSpan.children!.map((e) => e as TextSpan));
        //   }
        //   measuredWidthOfAllRichTexts += calculateTextSpanWidth(
        //     textSpan,
        //   );
        // }
        expect(
          approximatedWidth,
          moreOrLessEquals(measuredWidthOfAllRichTexts, epsilon: 5.0),
        );
      });
    });
  });
}

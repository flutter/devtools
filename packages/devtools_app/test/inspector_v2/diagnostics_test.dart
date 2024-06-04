// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/shared/ui/utils.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
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
      setEnableExperiments();
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    });

    group('hover eval', () {
      final nodeJson = <String, Object?>{
        'widgetRuntimeType': 'Row',
        'renderObject': renderObjectJson,
        'hasChildren': false,
        'children': [],
      };
      final inspectorService = MockInspectorObjectGroupBase();
      final diagnostic = RemoteDiagnosticsNode(
        nodeJson,
        inspectorService,
        false,
        null,
      );
      late DiagnosticsNodeDescription diagnosticsNodeDescription;

      setUp(() {
        preferences.inspectorV2.setHoverEvalMode(true);
        diagnosticsNodeDescription = DiagnosticsNodeDescription(
          diagnostic,
        );
      });

      testWidgets(
        'can be enabled from preferences',
        (WidgetTester tester) async {
          await tester.pumpWidget(wrap(diagnosticsNodeDescription));

          final hoverCardTooltip =
              tester.widget(find.byType(HoverCardTooltip)) as HoverCardTooltip;
          expect(hoverCardTooltip.enabled(), true);
        },
      );

      testWidgets(
        'can be disabled from preferences',
        (WidgetTester tester) async {
          preferences.inspectorV2.setHoverEvalMode(false);

          await tester.pumpWidget(wrap(diagnosticsNodeDescription));

          final hoverCardTooltip =
              tester.widget(find.byType(HoverCardTooltip)) as HoverCardTooltip;
          expect(hoverCardTooltip.enabled(), false);
        },
      );

      testWidgets(
        'disabled when inspector service not set',
        (WidgetTester tester) async {
          final diagnosticWithoutService = RemoteDiagnosticsNode(
            nodeJson,
            null,
            false,
            null,
          );
          diagnosticsNodeDescription = DiagnosticsNodeDescription(
            diagnosticWithoutService,
          );

          await tester.pumpWidget(wrap(diagnosticsNodeDescription));

          final hoverCardTooltip =
              tester.widget(find.byType(HoverCardTooltip)) as HoverCardTooltip;
          expect(hoverCardTooltip.enabled(), false);
        },
      );
    });

    group('approximateNodeWidth', () {
      const epsilon = 7.0;
      testWidgets(
        'property diagnostics node with name and description',
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
            moreOrLessEquals(measuredWidthOfAllRichTexts, epsilon: epsilon),
          );
        },
      );

      testWidgets(
        'diagnostics node with icon and description',
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
              epsilon: epsilon,
            ),
          );
        },
      );

      testWidgets(
        'error node with different fontSize',
        (WidgetTester tester) async {
          // Nodes with normal levels default to using the default fontSize, so
          // using an error level node allows us to test different font sizes.
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

          //Use a textStyle that is much larger than the normal style
          const textStyle = TextStyle(fontSize: 24.0, fontFamily: 'Roboto');
          final diagnosticsNodeDescription = DiagnosticsNodeDescription(
            diagnosticWithoutService,
            style: textStyle,
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

          final measuredWidthOfAllRichTexts =
              allRichTexts.fold<double>(0, (previousValue, richText) {
            final originalTextSpan = richText.text as TextSpan;

            return previousValue +
                calculateTextSpanWidth(
                  originalTextSpan,
                );
          });

          expect(
            approximatedWidth,
            moreOrLessEquals(measuredWidthOfAllRichTexts, epsilon: epsilon),
          );
        },
      );
    });
  });
}

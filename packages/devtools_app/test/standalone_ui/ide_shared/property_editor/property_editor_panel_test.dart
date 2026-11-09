// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/primitives/query_parameters.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('propertyEditorDocumentationLink', () {
    const embedModeKey = 'embedMode';
    const embedOneValue = 'one';
    const vsCodeLink = 'https://docs.flutter.dev/tools/vs-code#property-editor';
    const androidStudioLink =
        'https://docs.flutter.dev/tools/android-studio#property-editor';

    test('is null when not embedded', () {
      expect(
        propertyEditorDocumentationLink(
          DevToolsQueryParams({
            DevToolsQueryParams.dashToolKey: 'vscode-plugins',
          }),
        ),
        isNull,
      );
    });

    test('links to VS Code docs for dashTool=vscode-plugins', () {
      expect(
        propertyEditorDocumentationLink(
          DevToolsQueryParams({
            embedModeKey: embedOneValue,
            DevToolsQueryParams.dashToolKey: 'vscode-plugins',
          }),
        ),
        vsCodeLink,
      );
    });

    test('links to VS Code docs for legacy ide=VSCode', () {
      expect(
        propertyEditorDocumentationLink(
          DevToolsQueryParams({
            embedModeKey: embedOneValue,
            DevToolsQueryParams.ideKey: 'VSCode',
          }),
        ),
        vsCodeLink,
      );
    });

    test('links to Android Studio docs for dashTool=intellij-plugins', () {
      expect(
        propertyEditorDocumentationLink(
          DevToolsQueryParams({
            embedModeKey: embedOneValue,
            DevToolsQueryParams.dashToolKey: 'intellij-plugins',
          }),
        ),
        androidStudioLink,
      );
    });

    test('defaults to Android Studio docs when no IDE is specified', () {
      expect(
        propertyEditorDocumentationLink(
          DevToolsQueryParams({embedModeKey: embedOneValue}),
        ),
        androidStudioLink,
      );
    });
  });
}

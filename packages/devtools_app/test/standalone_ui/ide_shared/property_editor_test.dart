// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/service/editor/api_classes.dart';
import 'package:devtools_app/src/shared/constants.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_sidebar.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/debug_sessions.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/scenes/standalone_ui/editor_service/simulated_editor.dart';
import '../../test_infra/utils/sidebar_utils.dart';

void main() {
  const propertyEditor = PropertyEditorSidebar();

  group('Property Editor input types', () {
    testWidgets('string input', (tester) async {
      await tester.pumpWidget(propertyEditor);

      final stringInput = find.ancestor(
        of: find.text('title'),
        matching: find.byType(TextFormField),
      );

      expect(stringInput, findsOneWidget);
    });
  });
}

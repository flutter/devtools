// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/diagnostics/diagnostics_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'layout_explorer_serialization_delegate.dart';

Future<RemoteDiagnosticsNode> widgetToLayoutExplorerRemoteDiagnosticsNode({
  required Widget widget,
  required WidgetTester tester,
  int subtreeDepth = 1,
}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
  final element = find.byWidget(widget).evaluate().first;
  final nodeJson =
      element.toDiagnosticsNode(style: DiagnosticsTreeStyle.dense).toJsonMap(
            LayoutExplorerSerializationDelegate(
              subtreeDepth: subtreeDepth,
              service: WidgetInspectorService.instance,
            ),
          );
  return RemoteDiagnosticsNode(nodeJson, null, false, null);
}

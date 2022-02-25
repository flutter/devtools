// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import '../debugger/codeview.dart';
import '../screens/inspector/inspector_service.dart';
import '../shared/common_widgets.dart';

abstract class DevToolsExtensionPoints {
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions();

  Link issueTrackerLink();

  String loadingAppSizeDataMessage();

  InspectorServiceBase inspectorServiceProvider();
}

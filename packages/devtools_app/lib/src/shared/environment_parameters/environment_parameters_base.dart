// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../screens/debugger/codeview.dart';
import '../common_widgets.dart';
import '../diagnostics/inspector_service.dart';

abstract class DevToolsEnvironmentParameters {
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions();

  GaLink issueTrackerLink({String? additionalInfo, String? issueTitle});

  String? username();

  String loadingAppSizeDataMessage();

  InspectorServiceBase? inspectorServiceProvider();

  GaLink? enableSourceMapsLink();

  String get perfettoIndexLocation;

  String? chrome115BreakpointBug();
}

// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../screens/debugger/codeview.dart';
import '../diagnostics/inspector_service.dart';
import '../ui/common_widgets.dart';

abstract class DevToolsEnvironmentParameters {
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions();

  GaLink issueTrackerLink({String? additionalInfo, String? issueTitle});

  String? username();

  String loadingAppSizeDataMessage();

  InspectorServiceBase? inspectorServiceProvider();

  GaLink? enableSourceMapsLink();

  String get perfettoIndexLocation;

  String? chrome115BreakpointBug();

  List<TextSpan>? recommendedDebuggers(
    BuildContext context, {
    required bool isFlutterApp,
  });
}

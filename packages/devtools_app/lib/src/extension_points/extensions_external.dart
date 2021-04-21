// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../common_widgets.dart';
import '../debugger/codeview.dart';
import 'extensions_base.dart';

class ExternalDevToolsExtensionPoints implements DevToolsExtensionPoints {
  @override
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions() =>
      <ScriptPopupMenuOption>[];

  @override
  Link issueTrackerLink() {
    const githubLink = 'github.com/flutter/devtools/issues';
    return const Link(display: githubLink, url: 'https://$githubLink');
  }
}

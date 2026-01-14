// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../../framework/scaffold/bottom_pane.dart';
import '../../ui/tab.dart';

class AiAssistantPane extends StatelessWidget implements TabbedPane {
  const AiAssistantPane({super.key});

  @override
  DevToolsTab get tab =>
      DevToolsTab.create(tabName: _tabName, gaPrefix: _gaPrefix);

  static const _tabName = 'AI Assistant';

  static const _gaPrefix = 'aiAssistant';

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(child: Center(child: Text('TODO: Implement AI Assistant.'))),
      ],
    );
  }
}

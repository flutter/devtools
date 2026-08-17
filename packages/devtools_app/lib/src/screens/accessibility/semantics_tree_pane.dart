// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/ui/common_widgets.dart';

/// A pane that displays the semantics tree of the connected app.
class AccessibilitySemanticsTreePane extends StatelessWidget {
  const AccessibilitySemanticsTreePane({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsAreaPane(
      header: AreaPaneHeader(
        title: Text('Semantics Tree'),
        includeTopBorder: false,
        roundedTopBorder: false,
      ),
      child: CenteredMessage(
        message:
            'Accessibility semantics tree placeholder.\n'
            '// TODO(hannah-hyj): Implement semantics tree view and details explorer.',
      ),
    );
  }
}

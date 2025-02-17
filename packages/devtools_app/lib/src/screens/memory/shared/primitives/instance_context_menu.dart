// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../../../shared/primitives/utils.dart';
import '../../../../shared/ui/common_widgets.dart';

typedef MenuBuilder = List<Widget> Function();

/// A display for count of instances that may include a context menu button.
class InstanceViewWithContextMenu extends StatelessWidget {
  const InstanceViewWithContextMenu({
    super.key,
    required this.count,
    required this.menuBuilder,
  }) : assert(count >= 0);

  final int count;
  final MenuBuilder? menuBuilder;

  @override
  Widget build(BuildContext context) {
    final menu = menuBuilder?.call() ?? [];
    final shouldShowMenu = menu.isNotEmpty && count > 0;
    const menuButtonWidth = ContextMenuButton.defaultWidth;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(child: Text(nf.format(count), textAlign: TextAlign.end)),
        if (shouldShowMenu)
          ContextMenuButton(
            // ignore: avoid_redundant_argument_values, ensures consistency with [SizedBox] below.
            buttonWidth: menuButtonWidth,
            menuChildren: menu,
          )
        else
          const SizedBox(width: menuButtonWidth),
      ],
    );
  }
}

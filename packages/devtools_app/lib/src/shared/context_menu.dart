// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analytics/analytics.dart' as ga;

class ContextMenuButton extends StatefulWidget {
  const ContextMenuButton({
    this.tooltip = 'Open context menu',
    this.buttonKey,
    this.size,
    this.style,
    this.gaScreen,
    this.gaItem,
  });

  static const double width = 14;

  final TextStyle? style;
  final String tooltip;
  final Key? buttonKey;
  final double? size;
  final String? gaScreen;
  final String? gaItem;

  @override
  State<ContextMenuButton> createState() => _ContextMenuButtonState();
}

class _ContextMenuButtonState extends State<ContextMenuButton> {
  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Menu Button');

  @override
  Widget build(BuildContext context) {
    final onPressed = () {
      if (widget.gaScreen != null && widget.gaItem != null) {
        ga.select(widget.gaScreen!, widget.gaItem!);
      }
    };

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          child: Text('MenuEntry.about.label'),
          onPressed: () => print('click'),
        ),
        MenuItemButton(
          child: Text('MenuEntry.about.label'),
          onPressed: () => print('click'),
        ),
        MenuItemButton(
          child: Text('MenuEntry.about.label'),
          onPressed: () => print('click'),
        ),
        MenuItemButton(
          child: Text('MenuEntry.about.label'),
          onPressed: () => print('click'),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: () => print('click'),
              child: Text('MenuEntry.colorRed.label'),
            ),
            MenuItemButton(
              onPressed: () => print('click'),
              child: Text('MenuEntry.colorGreen.label'),
            ),
            MenuItemButton(
              onPressed: () => print('click'),
              child: Text('MenuEntry.colorBlue.label'),
            ),
          ],
          child: const Text('Background Color'),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        return TextButton(
          focusNode: _buttonFocusNode,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: _MenuButton(style: widget.style),
        );
      },
    );
  }

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    super.dispose();
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ContextMenuButton.width,
      child: MaterialButton(
        padding: const EdgeInsets.all(0),
        onPressed: null,
        child: Text('⋮', style: style, textAlign: TextAlign.center),
      ),
    );
  }
}

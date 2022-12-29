// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'analytics/analytics.dart' as ga;

class ContextMenuButton extends StatefulWidget {
  const ContextMenuButton({
    this.style,
    this.gaScreen,
    this.gaItem,
    required this.menu,
  });

  static const double width = 14;

  final TextStyle? style;
  final String? gaScreen;
  final String? gaItem;
  final List<Widget> menu;

  @override
  State<ContextMenuButton> createState() => _ContextMenuButtonState();
}

class _ContextMenuButtonState extends State<ContextMenuButton> {
  //final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Menu Button');

  @override
  Widget build(BuildContext context) {
    final onPressed = () {
      if (widget.gaScreen != null && widget.gaItem != null) {
        ga.select(widget.gaScreen!, widget.gaItem!);
      }
    };

    return MenuAnchor(
      menuChildren: widget.menu,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        return _MenuButton(style: widget.style, controller: controller);
      },
    );
  }

  @override
  void dispose() {
    //_buttonFocusNode.dispose();
    super.dispose();
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({this.style, required this.controller});

  final TextStyle? style;
  final MenuController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ContextMenuButton.width,
      child: MaterialButton(
        padding: const EdgeInsets.all(0),
        child: Text('⋮', style: style, textAlign: TextAlign.center),
        //focusNode: _buttonFocusNode,
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
      ),
    );
  }
}

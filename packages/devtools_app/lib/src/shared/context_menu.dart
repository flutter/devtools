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
  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: widget.menu,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        return SizedBox(
          width: ContextMenuButton.width,
          child: TextButton(
            child: Text('⋮', style: widget.style, textAlign: TextAlign.center),
            onPressed: () {
              if (widget.gaScreen != null && widget.gaItem != null) {
                ga.select(widget.gaScreen!, widget.gaItem!);
              }
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          ),
        );
      },
    );
  }
}

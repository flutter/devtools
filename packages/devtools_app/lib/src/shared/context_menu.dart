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
  //MenuEntry? _lastSelection;
  //final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Menu Button');

  @override
  Widget build(BuildContext context) {
    final onPressed = () {
      if (widget.gaScreen != null && widget.gaItem != null) {
        ga.select(widget.gaScreen!, widget.gaItem!);
      }
    };

    return SizedBox(
      width: ContextMenuButton.width,
      child: MaterialButton(
        padding: const EdgeInsets.all(0),
        onPressed: onPressed,
        key: widget.buttonKey,
        child: Text('⋮', style: widget.style, textAlign: TextAlign.center),
      ),
    );
  }
}

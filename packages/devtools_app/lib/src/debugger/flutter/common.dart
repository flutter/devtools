// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/theme.dart';
import 'debugger_screen.dart';

/// Create a header area for a debugger component.
///
/// Either one of [text] or [child] must be supplied.
Container debuggerSectionTitle(ThemeData theme, {String text, Widget child}) {
  assert(text != null || child != null);
  assert(text == null || child == null);

  return Container(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: theme.focusColor),
      ),
      color: titleSolidBackgroundColor(theme),
    ),
    padding: const EdgeInsets.only(left: defaultSpacing),
    alignment: Alignment.centerLeft,
    height: DebuggerScreen.debuggerPaneHeaderHeight,
    child: child != null ? child : Text(text, style: theme.textTheme.subtitle2),
  );
}

Widget createCircleWidget(double radius, Color color) {
  return Container(
    width: radius,
    height: radius,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

Widget createAnimatedCircleWidget(double radius, Color color) {
  return AnimatedContainer(
    width: radius,
    height: radius,
    curve: defaultCurve,
    duration: defaultDuration,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A wrapper around a FlatButton and an Icon, used for small toolbar actions.
class DebuggerToolbarAction extends StatelessWidget {
  const DebuggerToolbarAction(
    this.icon, {
    @required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: onPressed,
      child: Icon(icon, size: actionsIconSize),
    );
  }
}

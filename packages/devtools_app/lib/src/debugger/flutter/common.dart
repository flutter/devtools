// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/theme.dart';
import 'debugger_screen.dart';

Widget densePadding(Widget child) {
  return Padding(
    padding: const EdgeInsets.all(2.0),
    child: child,
  );
}

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
      color: titleSolidBackgroundColor,
    ),
    padding: const EdgeInsets.only(left: defaultSpacing),
    alignment: Alignment.centerLeft,
    height: DebuggerScreen.debuggerPaneHeaderHeight,
    child: child != null
        ? child
        : Text(
            text,
            style: theme.textTheme.subtitle2,
          ),
  );
}

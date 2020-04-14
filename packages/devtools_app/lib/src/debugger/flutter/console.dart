// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/theme.dart';
import 'debugger_screen.dart';

class Console extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedBorder(
      child: Column(
        children: [
          buildTitle('Console', theme),
          const Expanded(
            child: Center(child: Text('todo:')),
          ),
        ],
      ),
    );
  }

  Container buildTitle(String title, ThemeData theme) {
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
      child: Text(
        title,
        style: theme.textTheme.subtitle2,
      ),
    );
  }
}

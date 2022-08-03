// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../shared/theme.dart';

/// Display a single bullet character in order to act as a stylized spacer
/// component.
class BulletSpacer extends StatelessWidget {
  const BulletSpacer({this.useAccentColor = false});

  final bool useAccentColor;

  static double get width => actionWidgetSize / 2;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    late TextStyle? textStyle;
    if (useAccentColor) {
      textStyle = theme.appBarTheme.toolbarTextStyle ??
          theme.primaryTextTheme.bodyText2;
    } else {
      textStyle = theme.textTheme.bodyText2;
    }

    final mutedColor = textStyle?.color?.withAlpha(0x90);

    return Container(
      width: width,
      height: actionWidgetSize,
      alignment: Alignment.center,
      child: Text(
        '•',
        style: textStyle?.copyWith(color: mutedColor),
      ),
    );
  }
}

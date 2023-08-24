// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/utils.dart';

/// Create a header area for a debugger component.
///
/// Either one of [text] or [child] must be supplied.
Widget debuggerSectionTitle(ThemeData theme, {String? text, Widget? child}) {
  assert(text != null || child != null);
  assert(text == null || child == null);

  return OutlineDecoration.onlyBottom(
    child: SizedBox(
      height: defaultHeaderHeight(isDense: isDense()),
      child: Container(
        padding: const EdgeInsets.only(left: defaultSpacing),
        alignment: Alignment.centerLeft,
        height: areaPaneHeaderHeight,
        child: child ?? Text(text!, style: theme.textTheme.titleSmall),
      ),
    ),
  );
}

Widget createCircleWidget(double radius, Color? color) {
  return Container(
    width: radius,
    height: radius,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

Widget createAnimatedCircleWidget(double radius, Color? color) {
  return AnimatedContainer(
    width: radius,
    height: radius,
    curve: defaultCurve,
    duration: defaultDuration,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

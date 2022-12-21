// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/common_widgets.dart';
import '../../../shared/theme.dart';
import 'primitives/class_name.dart';

class HeapClassView extends StatelessWidget {
  const HeapClassView({
    super.key,
    required this.theClass,
    this.showCopyButton = false,
    this.copyGaItem,
    this.textStyle,
  });

  final HeapClassName theClass;
  final bool showCopyButton;
  final String? copyGaItem;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: maybeWrapWithTooltip(
            tooltip: theClass.fullName,
            child: Text(
              theClass.shortName,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ),
        if (showCopyButton)
          CopyToClipboardControl(
            dataProvider: () => theClass.fullName,
            tooltip: 'Copy full class name to clipboard.',
            size: tableIconSize,
            style: textStyle,
            gaScreen: gac.memory,
            gaItem: copyGaItem,
          ),
      ],
    );
  }
}

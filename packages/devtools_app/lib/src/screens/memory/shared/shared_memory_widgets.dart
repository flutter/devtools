// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/common_widgets.dart';
import '../../../shared/memory/class_name.dart';
import '../../../shared/theme.dart';

class HeapClassView extends StatelessWidget {
  const HeapClassView({
    super.key,
    required this.theClass,
    required this.rootPackage,
    this.showCopyButton = false,
    this.copyGaItem,
  });

  final HeapClassName theClass;
  final bool showCopyButton;
  final String? copyGaItem;
  final String? rootPackage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: maybeWrapWithTooltip(
            tooltip:
                '${theClass.classType(rootPackage).classTooltip}\n${theClass.fullName}',
            child: Row(
              children: [
                theClass.classType(rootPackage).icon,
                const SizedBox(width: denseSpacing),
                Expanded(
                  child: Text(
                    theClass.shortName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showCopyButton)
          CopyToClipboardControl(
            dataProvider: () => theClass.fullName,
            tooltip: 'Copy full class name to clipboard.',
            size: tableIconSize,
            gaScreen: gac.memory,
            gaItem: copyGaItem,
          ),
      ],
    );
  }
}

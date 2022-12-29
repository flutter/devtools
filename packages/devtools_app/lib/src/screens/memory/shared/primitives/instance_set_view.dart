// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/context_menu.dart';

typedef SampleObtainer = InstanceRef Function();

class InstanceSetView extends StatelessWidget {
  const InstanceSetView({
    super.key,
    required this.count,
    required this.sampleObtainer,
    required this.showMenu,
    this.textStyle,
    required this.gaContext,
  }) : assert(showMenu == (sampleObtainer != null));

  final int count;
  final SampleObtainer? sampleObtainer;
  final bool showMenu;
  final TextStyle? textStyle;
  final MemoryAreas gaContext;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.decimalPattern();

    return Row(
      children: [
        Text(
          format.format(count),
          style: textStyle,
        ),
        if (showMenu) ContextMenuButton(style: textStyle),
        if (!showMenu) const SizedBox(width: ContextMenuButton.width),
      ],
    );
  }
}

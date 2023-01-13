// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/primitives/utils.dart';

abstract class SampleObtainer {
  Future<void> obtain();
}

class InstanceSetView extends StatelessWidget {
  const InstanceSetView({
    super.key,
    this.textStyle,
    required this.count,
    required this.sampleObtainer,
    required this.showMenu,
    required this.gaContext,
  }) : assert(showMenu == (sampleObtainer != null));

  final int count;
  final SampleObtainer? sampleObtainer;
  final bool showMenu;
  final TextStyle? textStyle;
  final MemoryAreas gaContext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          nf.format(count),
          style: textStyle,
        ),
        if (showMenu)
          ContextMenuButton(
            style: textStyle,
            menu: _menu(sampleObtainer!),
          ),
        if (!showMenu) const SizedBox(width: ContextMenuButton.width),
      ],
    );
  }
}

class _MenuForSubset extends StatelessWidget {
  const _MenuForSubset(this.menuText, this.sampleObtainer);

  final String menuText;
  final SampleObtainer sampleObtainer;

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      menuChildren: <Widget>[
        MenuItemButton(
          onPressed: sampleObtainer.obtain,
          child: const Text('Fields'),
        ),
        const MenuItemButton(
          child: Text('Outgoing references'),
        ),
        const MenuItemButton(
          child: Text('Incoming references'),
        ),
      ],
      child: Text(menuText),
    );
  }
}

List<Widget> _menu(SampleObtainer sampleObtainer) => [
      _MenuForSubset(
        'Store one instance as a console variable',
        sampleObtainer,
      ),
      _MenuForSubset(
        'Store first 100 instances as a console variable',
        sampleObtainer,
      ),
      _MenuForSubset(
        'Store all instances as a console variable',
        sampleObtainer,
      ),
    ];

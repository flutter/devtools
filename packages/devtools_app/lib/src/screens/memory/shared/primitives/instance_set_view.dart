// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/common_widgets.dart';

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
        if (showMenu)
          ContextMenuButton(
            style: textStyle,
            menu: _menu(),
          ),
        if (!showMenu) const SizedBox(width: ContextMenuButton.width),
      ],
    );
  }
}

List<Widget> _menu() => [
      SubmenuButton(
        menuChildren: <Widget>[
          MenuItemButton(
            onPressed: () => print('get fields'),
            child: const Text('Fields'),
          ),
          const MenuItemButton(
            child: Text('Outgoing references'),
          ),
          const MenuItemButton(
            child: Text('Incoming references'),
          ),
        ],
        child: const Text('Store one instance as a console variable'),
      ),
      const SubmenuButton(
        menuChildren: <Widget>[
          MenuItemButton(
            child: Text('Fields'),
          ),
          MenuItemButton(
            child: Text('Outgoing references'),
          ),
          MenuItemButton(
            child: Text('Incoming references'),
          ),
        ],
        child: Text('Store 100 instances as a console variable'),
      ),
      const SubmenuButton(
        menuChildren: <Widget>[
          MenuItemButton(
            child: Text('Fields'),
          ),
          MenuItemButton(
            child: Text('Outgoing references'),
          ),
          MenuItemButton(
            child: Text('Incoming references'),
          ),
        ],
        child: Text('Store all instances as a console variable'),
      ),
    ];

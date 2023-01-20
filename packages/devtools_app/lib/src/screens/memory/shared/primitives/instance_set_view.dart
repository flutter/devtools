// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/primitives/utils.dart';

abstract class ClassSampler {
  Future<void> oneVariableToConsole();
  void instanceGraphToConsole();
  bool get isEvalEnabled;
}

/// A button with label '...' to show near count of instances,
/// with drop down menu to explore the instances.
class InstanceSetButton extends StatelessWidget {
  const InstanceSetButton({
    super.key,
    this.textStyle,
    required this.count,
    required this.sampleObtainer,
    required this.showMenu,
    required this.gaContext,
  }) : assert(showMenu == (sampleObtainer != null));

  final int count;
  final ClassSampler? sampleObtainer;
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

class _StoreAsVariableMenu extends StatelessWidget {
  const _StoreAsVariableMenu(this.sampleObtainer);

  final ClassSampler sampleObtainer;

  @override
  Widget build(BuildContext context) {
    final enabled = sampleObtainer.isEvalEnabled;
    const menuText = 'Store as a console variable';

    if (!enabled) {
      return const MenuItemButton(child: Text(menuText));
    }

    return SubmenuButton(
      menuChildren: <Widget>[
        MenuItemButton(
          onPressed: enabled ? sampleObtainer.oneVariableToConsole : null,
          child: const Text('One instance'),
        ),
        const MenuItemButton(
          child: Text('First 20 instances'),
        ),
        const MenuItemButton(
          child: Text('All instances'),
        ),
      ],
      child: const Text(menuText),
    );
  }
}

List<Widget> _menu(ClassSampler sampleObtainer) => [
      _StoreAsVariableMenu(sampleObtainer),
      MenuItemButton(
        onPressed: sampleObtainer.instanceGraphToConsole,
        child: const Text('Browse references for a single instance in console'),
      ),
    ];

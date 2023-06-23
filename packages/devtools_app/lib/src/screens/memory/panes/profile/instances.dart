// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/memory/class_name.dart';

import '../../shared/primitives/instance_context_menu.dart';

/// Right aligned table cell, shat shows number of instances.
///
/// If the row is selected and count of instances is positive, the table cell
/// includes a "more" icon button with a context menu for the instance set.
class ProfileInstanceTableCell extends StatelessWidget {
  const ProfileInstanceTableCell(
    this.heapClass,
    this.gaContext, {
    super.key,
    required bool isSelected,
    required this.count,
  }) : _shouldShowMenu = isSelected && count > 0;

  final MemoryAreas gaContext;
  final int count;
  final HeapClassName heapClass;
  final bool _shouldShowMenu;

  @override
  Widget build(BuildContext context) {
    return InstanceViewWithContextMenu(
      count: count,
      gaContext: gaContext,
      menuBuilder: _shouldShowMenu ? buildHeapInstancesMenu : null,
    );
  }
}

List<Widget> buildHeapInstancesMenu() {
  return [
    _StoreAsOneVariableMenu(),
    _StoreAllAsVariableMenu(),
  ];
}

class _StoreAllAsVariableMenu extends StatelessWidget {
  const _StoreAllAsVariableMenu();

  @override
  Widget build(BuildContext context) {
    const menuText = 'Store all class instances currently alive in application';

    MenuItemButton item(
      title, {
      required bool subclasses,
      required bool implementers,
    }) =>
        MenuItemButton(
          onPressed: () {},
          child: Text(title),
        );

    return SubmenuButton(
      menuChildren: <Widget>[
        item('Direct instances', implementers: false, subclasses: false),
        item('Direct and subclasses', implementers: false, subclasses: false),
        item('Direct and implementers', implementers: false, subclasses: false),
        item(
          'Direct, subclasses, and implementers',
          implementers: false,
          subclasses: false,
        ),
      ],
      child: const Text(menuText),
    );
  }
}

class _StoreAsOneVariableMenu extends StatelessWidget {
  const _StoreAsOneVariableMenu();

  @override
  Widget build(BuildContext context) {
    const menuText = 'Store one instance from the set as a console variable';

    return SubmenuButton(
      menuChildren: <Widget>[
        MenuItemButton(
          onPressed: () {},
          child: const Text(
            'Any',
          ),
        ),
        MenuItemButton(
          onPressed: () {},
          child: const Text(
            'Any, not garbage collected',
          ),
        ),
      ],
      child: const Text(menuText),
    );
  }
}

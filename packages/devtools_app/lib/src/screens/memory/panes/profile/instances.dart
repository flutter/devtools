// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/memory/class_name.dart';

import '../../shared/heap/sampler.dart';
import '../../shared/primitives/instance_context_menu.dart';

/// Right aligned table cell, shat shows number of instances.
///
/// If the row is selected and count of instances is positive, the table cell
/// includes a "more" icon button with a context menu for the instance set.
class ProfileInstanceTableCell extends StatelessWidget {
  ProfileInstanceTableCell(
    this.heapClass,
    this.gaContext, {
    super.key,
    required bool isSelected,
    required this.count,
  }) : _shouldShowMenu = isSelected && count > 0;

  final MemoryAreas gaContext;
  final int count;
  final bool _shouldShowMenu;
  final HeapClassName heapClass;
  late final ClassSampler _sampler = ClassSampler(heapClass);

  @override
  Widget build(BuildContext context) {
    return InstanceViewWithContextMenu(
      count: count,
      menuBuilder: _shouldShowMenu ? _buildHeapInstancesMenu : null,
    );
  }

  List<Widget> _buildHeapInstancesMenu() {
    return [
      _StoreAsOneVariableMenu(_sampler),
      _StoreAllAsVariableMenu(_sampler),
    ];
  }
}

class _StoreAllAsVariableMenu extends StatelessWidget {
  const _StoreAllAsVariableMenu(this.sampler);

  final ClassSampler sampler;

  @override
  Widget build(BuildContext context) {
    const menuText = 'Store all class instances';

    MenuItemButton item(
      title, {
      required bool subclasses,
      required bool implementers,
    }) =>
        MenuItemButton(
          onPressed: () async => await sampler.allLiveToConsole(
            includeImplementers: implementers,
            includeSubclasses: subclasses,
          ),
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
  const _StoreAsOneVariableMenu(this.sampler);

  final ClassSampler sampler;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: sampler.oneLiveToConsole,
      child: const Text('Store one instance as a console variable'),
    );
  }
}

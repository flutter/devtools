// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/utils.dart';

abstract class ClassSampler {
  /// Drop one variable, which exists in static set and still alive in app, to console.
  Future<void> oneLiveStaticToConsole();

  /// Drop one variable from static set, to console.
  Future<void> oneStaticToConsole();

  /// Drop all live instances to console.
  Future<void> manyLiveToConsole();

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
    required this.liveItemsEnabled,
  })  : assert(showMenu == (sampleObtainer != null)),
        assert(count >= 0);

  final int count;
  final ClassSampler? sampleObtainer;
  final bool showMenu;
  final TextStyle? textStyle;
  final MemoryAreas gaContext;

  /// If true, menu items that show live objects, will be enabled.
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    final shouldShowMenu = showMenu && count > 0;

    return Row(
      children: [
        Text(
          nf.format(count),
          style: textStyle,
        ),
        if (shouldShowMenu)
          ContextMenuButton(
            style: textStyle,
            menu: _menu(
              sampleObtainer!,
              liveItemsEnabled: liveItemsEnabled,
            ),
          ),
        if (!shouldShowMenu) const SizedBox(width: ContextMenuButton.width),
      ],
    );
  }
}

class _StoreAsVariableMenu extends StatelessWidget {
  const _StoreAsVariableMenu(
    this.sampleObtainer, {
    required this.liveItemsEnabled,
  });

  final ClassSampler sampleObtainer;
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    final enabled = sampleObtainer.isEvalEnabled;
    const menuText = 'Store as a console variable';
    final limit = preferences.memory.refLimit.value;

    if (!enabled) {
      return const MenuItemButton(child: Text(menuText));
    }

    return SubmenuButton(
      // TODO(polina-c): change structure and review texts before opening the feature.
      menuChildren: <Widget>[
        MenuItemButton(
          onPressed:
              liveItemsEnabled ? sampleObtainer.oneLiveStaticToConsole : null,
          child: const Text(
            'One instance that exists in snapshot, and is alive in application',
          ),
        ),
        MenuItemButton(
          onPressed: sampleObtainer.oneStaticToConsole,
          child: const Text(
            'One instance from snapshot',
          ),
        ),
        MenuItemButton(
          onPressed: sampleObtainer.manyLiveToConsole,
          child: Text('Up to $limit instances, currently alive in application'),
        ),
      ],
      child: const Text(menuText),
    );
  }
}

List<Widget> _menu(
  ClassSampler sampleObtainer, {
  required bool liveItemsEnabled,
}) =>
    [
      _StoreAsVariableMenu(sampleObtainer, liveItemsEnabled: liveItemsEnabled),
    ];

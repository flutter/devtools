// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/primitives/utils.dart';

abstract class ClassSampler {
  /// Drop one variable, which exists in static set and still alive in app, to console.
  Future<void> oneLiveStaticToConsole();

  /// Drop one variable from static set, to console.
  Future<void> oneStaticToConsole();

  /// Drop all live instances to console.
  Future<void> allLiveToConsole({
    required bool includeSubclasses,
    required bool includeImplementers,
  });

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

class _StoreAsOneVariableMenu extends StatelessWidget {
  const _StoreAsOneVariableMenu(
    this.sampler, {
    required this.liveItemsEnabled,
  });

  final ClassSampler sampler;
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    final enabled = sampler.isEvalEnabled;
    const menuText = 'Store one instance as a console variable';

    if (!enabled) {
      return const MenuItemButton(child: Text(menuText));
    }

    return SubmenuButton(
      menuChildren: <Widget>[
        MenuItemButton(
          onPressed: sampler.oneStaticToConsole,
          child: const Text(
            'Any from snapshot',
          ),
        ),
        MenuItemButton(
          onPressed: liveItemsEnabled ? sampler.oneLiveStaticToConsole : null,
          child: const Text(
            'Any from snapshot, not garbage collected',
          ),
        ),
      ],
      child: const Text(menuText),
    );
  }
}

class _StoreAllAsVariableMenu extends StatelessWidget {
  const _StoreAllAsVariableMenu(
    this.sampler, {
    required this.liveItemsEnabled,
  });

  final ClassSampler sampler;
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    final enabled = sampler.isEvalEnabled;
    const menuText = 'Store all instances, currently alive in application';

    if (!enabled) {
      return const MenuItemButton(child: Text(menuText));
    }

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
          'Direct, subclasses and implementers',
          implementers: false,
          subclasses: false,
        ),
      ],
      child: const Text(menuText),
    );
  }
}

// TODO(polina-c): review structure/texts and add ga, before opening the feature.
List<Widget> _menu(
  ClassSampler sampler, {
  required bool liveItemsEnabled,
}) {
  return [
    _StoreAsOneVariableMenu(sampler, liveItemsEnabled: liveItemsEnabled),
    _StoreAllAsVariableMenu(sampler, liveItemsEnabled: liveItemsEnabled),
  ];
}

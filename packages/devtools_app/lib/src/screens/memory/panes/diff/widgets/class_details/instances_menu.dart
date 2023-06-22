// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../controller/sampler.dart';

List<Widget> buildHeapInstancesMenu({
  required HeapClassSampler? sampler,
  required bool liveItemsEnabled,
}) {
  if (sampler == null) return [];
  return [
    _StoreAsOneVariableMenu(sampler, liveItemsEnabled: liveItemsEnabled),
    _StoreAllAsVariableMenu(sampler, liveItemsEnabled: liveItemsEnabled),
  ];
}

class _StoreAllAsVariableMenu extends StatelessWidget {
  const _StoreAllAsVariableMenu(
    this.sampler, {
    required this.liveItemsEnabled,
  });

  final HeapClassSampler sampler;
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    final enabled = sampler.isEvalEnabled;
    const menuText = 'Store all class instances currently alive in application';

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
  const _StoreAsOneVariableMenu(
    this.sampler, {
    required this.liveItemsEnabled,
  });

  final HeapClassSampler sampler;
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    final enabled = sampler.isEvalEnabled;
    const menuText = 'Store one instance from the set as a console variable';

    if (!enabled) {
      return const MenuItemButton(child: Text(menuText));
    }

    return SubmenuButton(
      menuChildren: <Widget>[
        MenuItemButton(
          onPressed: sampler.oneStaticToConsole,
          child: const Text(
            'Any',
          ),
        ),
        MenuItemButton(
          onPressed: liveItemsEnabled ? sampler.oneLiveStaticToConsole : null,
          child: const Text(
            'Any, not garbage collected',
          ),
        ),
      ],
      child: const Text(menuText),
    );
  }
}

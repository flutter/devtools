// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/memory/heap_object.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/memory/new/classes.dart';
import '../../../shared/heap/sampler.dart';
import '../../../shared/primitives/instance_context_menu.dart';

/// Right aligned table cell, shat shows number of instances.
///
/// If the row is selected and count of instances is positive, the table cell
/// includes a "more" icon button with a context menu for the instance set.
class HeapInstanceTableCell extends StatelessWidget {
  HeapInstanceTableCell(
    ObjectSet objects,
    HeapDataCallback heap,
    HeapClassName heapClass, {
    super.key,
    required bool isSelected,
    this.liveItemsEnabled = true,
  })  : _sampleObtainer = _shouldShowMenu(isSelected, objects)
            ? HeapClassSampler(heapClass, objects, heap())
            : null,
        _count = objects.instanceCount;

  static bool _shouldShowMenu(bool isSelected, ObjectSet objects) =>
      isSelected && objects.instanceCount > 0;

  final HeapClassSampler? _sampleObtainer;

  final int _count;
  final bool liveItemsEnabled;

  @override
  Widget build(BuildContext context) {
    return InstanceViewWithContextMenu(
      count: _count,
      menuBuilder: () => _buildHeapInstancesMenu(
        sampler: _sampleObtainer,
        liveItemsEnabled: liveItemsEnabled,
      ),
    );
  }
}

List<Widget> _buildHeapInstancesMenu({
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
      String title, {
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
          child: const Text('Any'),
        ),
        MenuItemButton(
          onPressed: liveItemsEnabled ? sampler.oneLiveStaticToConsole : null,
          child: const Text('Any, not garbage collected'),
        ),
      ],
      child: const Text(menuText),
    );
  }
}

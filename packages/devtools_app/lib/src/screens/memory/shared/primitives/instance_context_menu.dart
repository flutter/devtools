// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/primitives/utils.dart';

typedef MenuBuilder = List<Widget> Function();

/// A display for count of instances that may include a context menu button.
class InstanceViewWithContextMenu extends StatelessWidget {
  const InstanceViewWithContextMenu({
    super.key,
    required this.count,
    required this.gaContext,
    required this.menuBuilder,
  }) : assert(count >= 0);

  final int count;
  final MenuBuilder? menuBuilder;
  final MemoryAreas gaContext;

  @override
  Widget build(BuildContext context) {
    final menu = menuBuilder?.call() ?? [];
    final shouldShowMenu = menu.isNotEmpty && count > 0;
    const menuButtonWidth = ContextMenuButton.defaultWidth;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(nf.format(count)),
        if (shouldShowMenu)
          ContextMenuButton(
            // ignore: avoid_redundant_argument_values, ensures consistency with [SizedBox] below.
            buttonWidth: menuButtonWidth,
            menuChildren: menu,
          )
        else
          const SizedBox(width: menuButtonWidth),
      ],
    );
  }
}

// abstract class ClassSampler {
//   /// Drop one variable, which exists in the static set and still alive in app, to console.
//   Future<void> oneLiveStaticToConsole();

//   /// Drop one variable from the static set, to console.
//   Future<void> oneStaticToConsole();

//   /// Drop all live instances to console.
//   Future<void> allLiveToConsole({
//     required bool includeSubclasses,
//     required bool includeImplementers,
//   });

//   bool get isEvalEnabled;
// }

// /// A display for an instance set that includes a context menu button when
// /// [showMenu] is true.
// ///
// /// The context menu provides options to explore the instances in the set.
// class InstanceDisplayWithContextMenu extends StatelessWidget {
//   const InstanceDisplayWithContextMenu({
//     super.key,
//     required this.count,
//     required this.sampleObtainer,
//     required this.showMenu,
//     required this.gaContext,
//     required this.liveItemsEnabled,
//   })  : assert(showMenu == (sampleObtainer != null)),
//         assert(count >= 0);

//   final int count;
//   final ClassSampler? sampleObtainer;
//   final bool showMenu;
//   final MemoryAreas gaContext;

//   /// If true, menu items that show live objects, will be enabled.
//   final bool liveItemsEnabled;

//   @override
//   Widget build(BuildContext context) {
//     final shouldShowMenu = showMenu && count > 0;
//     const menuButtonWidth = ContextMenuButton.defaultWidth;

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         Text(nf.format(count)),
//         if (shouldShowMenu)
//           ContextMenuButton(
//             // ignore: avoid_redundant_argument_values, ensures consistency with [SizedBox] below.
//             buttonWidth: menuButtonWidth,
//             menuChildren: _menu(
//               sampleObtainer!,
//               liveItemsEnabled: liveItemsEnabled,
//             ),
//           )
//         else
//           const SizedBox(width: menuButtonWidth),
//       ],
//     );
//   }
// }

// class _StoreAsOneVariableMenu extends StatelessWidget {
//   const _StoreAsOneVariableMenu(
//     this.sampler, {
//     required this.liveItemsEnabled,
//   });

//   final ClassSampler sampler;
//   final bool liveItemsEnabled;

//   @override
//   Widget build(BuildContext context) {
//     final enabled = sampler.isEvalEnabled;
//     const menuText = 'Store one instance from the set as a console variable';

//     if (!enabled) {
//       return const MenuItemButton(child: Text(menuText));
//     }

//     return SubmenuButton(
//       menuChildren: <Widget>[
//         MenuItemButton(
//           onPressed: sampler.oneStaticToConsole,
//           child: const Text(
//             'Any',
//           ),
//         ),
//         MenuItemButton(
//           onPressed: liveItemsEnabled ? sampler.oneLiveStaticToConsole : null,
//           child: const Text(
//             'Any, not garbage collected',
//           ),
//         ),
//       ],
//       child: const Text(menuText),
//     );
//   }
// }

// class _StoreAllAsVariableMenu extends StatelessWidget {
//   const _StoreAllAsVariableMenu(
//     this.sampler, {
//     required this.liveItemsEnabled,
//   });

//   final ClassSampler sampler;
//   final bool liveItemsEnabled;

//   @override
//   Widget build(BuildContext context) {
//     final enabled = sampler.isEvalEnabled;
//     const menuText = 'Store all class instances currently alive in application';

//     if (!enabled) {
//       return const MenuItemButton(child: Text(menuText));
//     }

//     MenuItemButton item(
//       title, {
//       required bool subclasses,
//       required bool implementers,
//     }) =>
//         MenuItemButton(
//           onPressed: () async => await sampler.allLiveToConsole(
//             includeImplementers: implementers,
//             includeSubclasses: subclasses,
//           ),
//           child: Text(title),
//         );

//     return SubmenuButton(
//       menuChildren: <Widget>[
//         item('Direct instances', implementers: false, subclasses: false),
//         item('Direct and subclasses', implementers: false, subclasses: false),
//         item('Direct and implementers', implementers: false, subclasses: false),
//         item(
//           'Direct, subclasses, and implementers',
//           implementers: false,
//           subclasses: false,
//         ),
//       ],
//       child: const Text(menuText),
//     );
//   }
// }

// List<Widget> _menu(
//   ClassSampler sampler, {
//   required bool liveItemsEnabled,
// }) {
//   return [
//     _StoreAsOneVariableMenu(sampler, liveItemsEnabled: liveItemsEnabled),
//     _StoreAllAsVariableMenu(sampler, liveItemsEnabled: liveItemsEnabled),
//   ];
// }

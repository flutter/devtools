// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'memory_controller.dart';

/// Top 10 matches to display in auto-complete overlay.
const topMatchesLimit = 10;

final memorySearchFieldKey = GlobalKey(debugLabel: 'MemorySearchFieldKey');

/// Layer links autoComplete popup to the search TextField widget.
final LayerLink autoCompletelayerLink = LayerLink();

OverlayEntry autoCompleteOverlay;

OverlayEntry createAutoCompleteOverlay(MemoryController controller) {
  // Find the searchField and place overlay below bottom of TextField and
  // make overlay width of TextField.
  final RenderBox box = memorySearchFieldKey.currentContext.findRenderObject();

  final autoCompleteTiles = <ListTile>[];
  for (final matchedName in controller.searchAutoComplete.value) {
    autoCompleteTiles.add(
      ListTile(
        title: Text(matchedName),
        onTap: () {
          controller.selectTheSearch = true;
          controller.search = matchedName;
        },
      ),
    );
  }

  return OverlayEntry(
    builder: (context) {
      return Positioned(
        width: box.size.width,
        child: CompositedTransformFollower(
          link: autoCompletelayerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, box.size.height),
          child: Material(
            elevation: 4.0,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: autoCompleteTiles,
            ),
          ),
        ),
      );
    },
  );
}

void closeAutoCompleteOverlay() {
  autoCompleteOverlay?.remove();
  autoCompleteOverlay = null;
}

/// Helper setState callback when searchAutoCompleteNotifier changes, usage:
///
///     addAutoDisposeListener(controller.searchAutoCompleteNotifier, () {
///      setState(autoCompleteOverlaySetState(controller, context));
///     });
VoidCallback autoCompleteOverlaySetState(
  MemoryController controller,
  BuildContext context,
) {
  return () {
    if (autoCompleteOverlay != null) {
      closeAutoCompleteOverlay();
    }

    autoCompleteOverlay = createAutoCompleteOverlay(controller);
    Overlay.of(context).insert(autoCompleteOverlay);
  };
}

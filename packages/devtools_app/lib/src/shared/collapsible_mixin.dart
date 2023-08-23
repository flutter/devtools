// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

/// Provides [animations] triggered by toggling the expanded and visible state
/// of a widget.
///
/// See also:
/// * [TreeNodeWidget], which uses this mixin to manage state for animations
///   on expand and collapse of tree nodes.
mixin CollapsibleAnimationMixin<T extends StatefulWidget>
    on TickerProviderStateMixin<T> {
  /// Animation controller for animating the expand/collapse icon.
  late final AnimationController expandController;

  /// An animation that rotates the expand arrow
  /// from pointing right (0.75 full turns) to pointing down (1.0 full turns).
  late final Animation<double> expandArrowAnimation;

  /// A curved animation that matches [expandController], moving from 0.0 to 1.0
  /// Useful for animating the size of a child that is appearing.
  late final Animation<double> expandCurve;

  /// Visibility state of the collapsible.
  ///
  /// Implementations can be somewhat slow as the value is cached.
  bool shouldShow();

  /// Callback triggered when whether the collapsible is expanded changes.
  void onExpandChanged(bool expanded);

  /// Whether the collapsible is currently expanded.
  bool get isExpanded;

  @override
  void initState() {
    super.initState();
    expandController = defaultAnimationController(this);
    expandCurve = defaultCurvedAnimation(expandController);
    expandArrowAnimation =
        Tween<double>(begin: 0.75, end: 1.0).animate(expandCurve);
    if (isExpanded) {
      expandController.value = 1.0;
    }
  }

  @override
  void dispose() {
    expandController.dispose();
    super.dispose();
  }

  void setExpanded(bool expanded) {
    setState(() {
      if (expanded) {
        expandController.forward();
      } else {
        expandController.reverse();
      }
      onExpandChanged(expanded);
    });
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget as T);
    if (isExpanded) {
      expandController.forward();
    } else {
      expandController.reverse();
    }
  }
}

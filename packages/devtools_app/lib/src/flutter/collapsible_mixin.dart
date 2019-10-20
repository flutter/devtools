// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Provides [animations] triggered by toggling the expanded and visible state
/// of a widget.
///
/// When used to animate a tree of widgets, the [showController] will typically
/// be triggered when the parent widget is expanded.
///
/// See also:
/// * [TreeNodeWidget], which uses this mixin to manage state for animations
///   on expand and collapse of tree nodes.
mixin CollapsibleAnimationMixin<T extends StatefulWidget>
    on TickerProviderStateMixin<T> {
  // Animation controllers for bringing each node into the list,
  // animating the size from 0 to the appropriate height.
  AnimationController showController;
  Animation<double> showAnimation;

  // Animation controllers for animating the expand/collapse icon.
  AnimationController expandController;
  Animation<double> expandAnimation;

  /// Whether or not this widget is currently shown.
  ///
  /// This is the cached value of shouldShow.
  bool _show;

  /// Callback triggered when whether the collapsible is expanded changes.
  void onExpandChanged(bool expanded);

  /// Visibility state of the collapsible.
  ///
  /// Implementations can be somewhat slow as the value is cached.
  bool shouldShow();

  /// Whether the collapsible is currently expanded.
  bool get isExpanded;

  @override
  void initState() {
    super.initState();
    showController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    showAnimation = CurvedAnimation(
      curve: Curves.easeInOutCubic,
      parent: showController,
    );
    // An animation that rotates the expand arrow
    // from pointing right (0.75 full turns) to pointing down (1.0 full turns).
    expandAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(curve: Curves.easeInOutCubic, parent: expandController),
    );
    _show = shouldShow() ?? true;
    if (_show) {
      showController.value = 1.0;
    }
    if (isExpanded ?? false) {
      expandController.value = 1.0;
    }
  }

  @override
  void dispose() {
    showController.dispose();
    expandController.dispose();
    super.dispose();
  }

  void setExpanded(bool isExpanded) {
    setState(() {
      if (isExpanded) {
        expandController.forward();
      } else {
        expandController.reverse();
      }
      onExpandChanged(isExpanded);
    });
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _show = shouldShow();
    if (_show) {
      showController.forward();
    } else {
      showController.reverse();
    }
    if (isExpanded) {
      expandController.forward();
    } else {
      expandController.reverse();
    }
  }
}

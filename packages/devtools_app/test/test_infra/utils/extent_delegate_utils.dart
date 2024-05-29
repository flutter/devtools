// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
library;

import 'package:devtools_app/src/shared/primitives/extent_delegate_list.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class TestRenderSliverBoxChildManager extends RenderSliverBoxChildManager {
  TestRenderSliverBoxChildManager({
    required this.children,
    required this.extentDelegate,
  });

  late RenderSliverExtentDelegateBoxAdaptor _renderObject;
  bool _renderObjectInitialized = false;
  List<RenderBox> children;

  RenderSliverExtentDelegateBoxAdaptor createRenderSliverExtentDelegate() {
    assert(!_renderObjectInitialized);
    _renderObject = RenderSliverExtentDelegateBoxAdaptor(
      childManager: this,
      extentDelegate: extentDelegate,
    );
    _renderObjectInitialized = true;
    return _renderObject;
  }

  final ExtentDelegate extentDelegate;

  int? _currentlyUpdatingChildIndex;

  @override
  void createChild(int index, {required RenderBox? after}) {
    if (index < 0 || index >= children.length) return;
    try {
      _currentlyUpdatingChildIndex = index;
      _renderObject.insert(children[index], after: after);
    } finally {
      _currentlyUpdatingChildIndex = null;
    }
  }

  @override
  void removeChild(RenderBox child) {
    _renderObject.remove(child);
  }

  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) {
    assert(lastIndex! >= firstIndex!);
    return children.length *
        (trailingScrollOffset! - leadingScrollOffset!) /
        (lastIndex! - firstIndex! + 1);
  }

  @override
  int get childCount => children.length;

  @override
  void didAdoptChild(RenderBox child) {
    assert(_currentlyUpdatingChildIndex != null);
    final SliverMultiBoxAdaptorParentData childParentData =
        child.parentData as SliverMultiBoxAdaptorParentData;
    childParentData.index = _currentlyUpdatingChildIndex;
  }

  @override
  void setDidUnderflow(bool value) {}
}

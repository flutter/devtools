// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:collection/collection.dart' as collection;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'custom_pointer_scroll_view.dart';

/// Base class for delegate providing extent information for items in a list.
abstract class ExtentDelegate {
  /// Optional callback to execute after the layout of the extents is modified.
  VoidCallback onLayoutDirty;

  int get length;

  /// The main-axis extent of each item.
  double itemExtent(int index);

  /// The layout offset for the child with the given index.
  double layoutOffset(int index);

  /// The minimum child index that is visible at the given scroll offset.
  ///
  /// Implementations should take no more than O(log n) time.
  int minChildIndexForScrollOffset(double scrollOffset);

  /// The maximum child index that is visible at the given end scroll offset.
  ///
  /// Implementations should take no more than O(log n) time.
  /// Surprisingly, getMaxChildIndexForScrollOffset should be 1 less than
  /// getMinChildIndexForScrollOffset if the scrollOffset is right at the
  /// boundary between two items.
  int maxChildIndexForScrollOffset(double endScrollOffset);

  @mustCallSuper
  void recompute() {
    if (onLayoutDirty != null) {
      onLayoutDirty();
    }
  }
}

/// [ExtentDelegate] implementation for the case where sizes for each
/// item are known but absolute positions are not known.
class FixedExtentDelegate extends ExtentDelegate {
  FixedExtentDelegate({
    @required this.computeExtent,
    @required this.computeLength,
  }) {
    recompute();
  }

  // The _offsets list is intentionally one element larger than the length of
  // the list as it includes an offset at the end that is the offset after all
  // items in the list.
  List<double> _offsets;

  @override
  int get length => _offsets.length - 1;

  final double Function(int index) computeExtent;
  final int Function() computeLength;

  @override
  void recompute() {
    final length = computeLength();
    // The offsets list is one longer than the length of the list as we
    // want to query for _offsets(length) to cheaply determine the total size
    // of the list. Additionally, the logic for binary search assumes that we
    // have one offset past the end of the list.
    _offsets = List(length + 1);
    double offset = 0;
    // The first item in the list is at offset zero.
    // TODO(jacobr): remove this line once we have NNBD lists.
    _offsets[0] = 0;
    for (int i = 0; i < length; ++i) {
      offset += computeExtent(i);
      _offsets[i + 1] = offset;
    }

    super.recompute();
  }

  @override
  double itemExtent(int index) {
    if (index >= length) return 0;
    return _offsets[index + 1] - _offsets[index];
  }

  @override
  double layoutOffset(int index) {
    if (index >= _offsets.length) return _offsets.last;
    return _offsets[index];
  }

  @override
  int minChildIndexForScrollOffset(double scrollOffset) {
    int index = collection.lowerBound(_offsets, scrollOffset);
    if (index == 0) return 0;
    if (index >= _offsets.length ||
        (_offsets[index] - scrollOffset).abs() > precisionErrorTolerance) {
      index--;
    }
    assert(_offsets[index] <= scrollOffset + precisionErrorTolerance);
    return index;
  }

  @override
  int maxChildIndexForScrollOffset(double endScrollOffset) {
    int index = collection.lowerBound(_offsets, endScrollOffset);
    if (index == 0) return 0;
    index--;
    assert(_offsets[index] < endScrollOffset);
    return index;
  }
}

/// A scrollable list of widgets arranged linearly where each item has an extent
/// specified by the [extentDelegate].
///
/// This class is inspired by the functionality in [ListView] where
/// `itemExtent` is specified. The difference is the extentDelegate provided
/// here specifies different extents for each item in the list and provides
/// the ability to animate extents without rebuilding the list. You should use
/// ListView instead for the simpler case where all items have the same extent.
///
/// Using this class is more efficient than using a ListView without specifying
/// itemExtent as only items visible on screen need to be built and laid out.
/// This class is more robust than ListView for cases where ListView items off
/// screen need to be animated.
class ExtentDelegateListView extends CustomPointerScrollView {
  const ExtentDelegateListView({
    Key key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController controller,
    bool primary,
    ScrollPhysics physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry padding,
    @required this.childrenDelegate,
    @required this.extentDelegate,
    int semanticChildCount,
    Function(PointerSignalEvent event) customPointerSignalHandler,
  })  : assert(childrenDelegate != null),
        super(
          key: key,
          scrollDirection: scrollDirection,
          reverse: reverse,
          controller: controller,
          primary: primary,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          semanticChildCount: semanticChildCount,
          customPointerSignalHandler: customPointerSignalHandler,
        );

  /// A delegate that provides the children for the [ExtentDelegateListView].
  final SliverChildDelegate childrenDelegate;

  /// A delegate that provides item extents for the children of the
  /// [ExtentDelegateListView].
  final ExtentDelegate extentDelegate;

  @override
  Widget buildChildLayout(BuildContext context) {
    return SliverExtentDelegateList(
      delegate: childrenDelegate,
      extentDelegate: extentDelegate,
    );
  }
}

/// A sliver that places multiple box children in a linear array.
///
/// The main axis extents on each child are specified by a delegate.
///
/// This class is inspired by [SliverFixedExtentList] which provides similar
/// functionality for the case where all items have the same extent.
class SliverExtentDelegateList extends SliverMultiBoxAdaptorWidget {
  /// Creates a sliver that places box children with the same main axis extent
  /// in a linear array.
  const SliverExtentDelegateList({
    Key key,
    @required SliverChildDelegate delegate,
    @required this.extentDelegate,
  }) : super(key: key, delegate: delegate);

  /// The extent the children are forced to have in the main axis.
  final ExtentDelegate extentDelegate;

  @override
  RenderSliverExtentDelegateBoxAdaptor createRenderObject(
      BuildContext context) {
    final SliverMultiBoxAdaptorElement element = context;
    return RenderSliverExtentDelegateBoxAdaptor(
      childManager: element,
      extentDelegate: extentDelegate,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSliverExtentDelegateBoxAdaptor renderObject) {
    renderObject.markNeedsLayout();
    renderObject.extentDelegate = extentDelegate;
  }
}

/// A sliver that contains multiple box children that each have known extent
/// along the main axis.
///
/// This class is inspired by [RenderSliverFixedExtentBoxAdaptor] which provides
/// similar functionality for the case where all items have the same extent.
class RenderSliverExtentDelegateBoxAdaptor extends RenderSliverMultiBoxAdaptor {
  /// Creates a sliver that contains multiple box children each of which have
  /// extent along the main axis provided by [extentDelegate].
  ///
  /// The [childManager] argument must not be null.
  RenderSliverExtentDelegateBoxAdaptor({
    @required RenderSliverBoxChildManager childManager,
    @required ExtentDelegate extentDelegate,
  }) : super(childManager: childManager) {
    this.extentDelegate = extentDelegate;
  }

  set extentDelegate(ExtentDelegate delegate) {
    // We need to listen for when the delegate changes its layout.
    delegate.onLayoutDirty = markNeedsLayout;
    _extentDelegate = delegate;
  }

  ExtentDelegate _extentDelegate;

  /// Called to estimate the total scrollable extents of this object.
  ///
  /// Must return the total distance from the start of the child with the
  /// earliest possible index to the end of the child with the last possible
  /// index.
  ///
  /// By default, defers to [RenderSliverBoxChildManager.estimateMaxScrollOffset].
  @protected
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  }) {
    return childManager.estimateMaxScrollOffset(
      constraints,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      leadingScrollOffset: leadingScrollOffset,
      trailingScrollOffset: trailingScrollOffset,
    );
  }

  int _calculateLeadingGarbage(int firstIndex) {
    RenderBox walker = firstChild;
    int leadingGarbage = 0;
    while (walker != null && indexOf(walker) < firstIndex) {
      leadingGarbage += 1;
      walker = childAfter(walker);
    }
    return leadingGarbage;
  }

  int _calculateTrailingGarbage(int targetLastIndex) {
    RenderBox walker = lastChild;
    int trailingGarbage = 0;
    while (walker != null && indexOf(walker) > targetLastIndex) {
      trailingGarbage += 1;
      walker = childBefore(walker);
    }
    return trailingGarbage;
  }

  BoxConstraints buildChildConstraints(int index) {
    final currentItemExtent = _extentDelegate.itemExtent(index);
    return constraints.asBoxConstraints(
      minExtent: currentItemExtent,
      maxExtent: currentItemExtent,
    );
  }

  // This method is is a fork of RenderSliverFixedExtentBoxAdaptor.performLayout
  // where we defer computations about offsets to the _extendDelegate and try
  // to avoid logic only applicable if all children have the same extent.
  @override
  void performLayout() {
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final double scrollOffset =
        constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);
    final double remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);
    final double targetEndScrollOffset = scrollOffset + remainingExtent;

    final int firstIndex =
        _extentDelegate.minChildIndexForScrollOffset(scrollOffset);
    final int targetLastIndex = targetEndScrollOffset.isFinite
        ? _extentDelegate.maxChildIndexForScrollOffset(targetEndScrollOffset)
        : null;

    if (firstChild != null) {
      final int leadingGarbage = _calculateLeadingGarbage(firstIndex);
      final int trailingGarbage = _calculateTrailingGarbage(targetLastIndex);
      collectGarbage(leadingGarbage, trailingGarbage);
    } else {
      collectGarbage(0, 0);
    }

    if (firstChild == null) {
      if (!addInitialChild(
        index: firstIndex,
        layoutOffset: _extentDelegate.layoutOffset(firstIndex),
      )) {
        // There are either no children, or we are past the end of all our children.
        // If it is the latter, we will need to find the first available child.
        double max;
        if (childManager.childCount != null) {
          // TODO(jacobr): is this correct?
          // This matches the logic from sliver_fixed_extent_list but it seems
          // a little odd. This is only right if the childManager contains all
          // children added to the list view.
          max = _extentDelegate.layoutOffset(childManager.childCount);
        } else if (firstIndex <= 0) {
          max = 0.0;
        } else {
          // We will have to find it manually.
          int possibleFirstIndex = firstIndex - 1;
          while (possibleFirstIndex > 0 &&
              !addInitialChild(
                index: possibleFirstIndex,
                layoutOffset: _extentDelegate.layoutOffset(possibleFirstIndex),
              )) {
            possibleFirstIndex -= 1;
          }
          max = _extentDelegate.layoutOffset(possibleFirstIndex);
        }
        geometry = SliverGeometry(
          scrollExtent: max,
          maxPaintExtent: max,
        );
        childManager.didFinishLayout();
        return;
      }
    }

    RenderBox trailingChildWithLayout;

    for (int index = indexOf(firstChild) - 1; index >= firstIndex; --index) {
      final RenderBox child =
          insertAndLayoutLeadingChild(buildChildConstraints(index));
      if (child == null) {
        // Items before the previously first child are no longer present.
        // Reset the scroll offset to offset all items prior and up to the
        // missing item. Let parent re-layout everything.
        geometry = SliverGeometry(
          scrollOffsetCorrection: _extentDelegate.layoutOffset(index),
        );
        return;
      }
      final SliverMultiBoxAdaptorParentData childParentData = child.parentData;
      childParentData.layoutOffset = _extentDelegate.layoutOffset(index);
      assert(childParentData.index == index);
      trailingChildWithLayout ??= child;
    }

    if (trailingChildWithLayout == null) {
      firstChild.layout(buildChildConstraints(firstIndex));
      final SliverMultiBoxAdaptorParentData childParentData =
          firstChild.parentData;
      childParentData.layoutOffset = _extentDelegate.layoutOffset(firstIndex);
      trailingChildWithLayout = firstChild;
    }

    double estimatedMaxScrollOffset =
        _extentDelegate.layoutOffset(_extentDelegate.length);
    for (int index = indexOf(trailingChildWithLayout) + 1;
        targetLastIndex == null || index <= targetLastIndex;
        ++index) {
      RenderBox child = childAfter(trailingChildWithLayout);
      if (child == null || indexOf(child) != index) {
        child = insertAndLayoutChild(
          buildChildConstraints(index),
          after: trailingChildWithLayout,
        );
        if (child == null) {
          // We have run out of children.
          estimatedMaxScrollOffset = _extentDelegate.layoutOffset(index + 1);
          break;
        }
      } else {
        child.layout(buildChildConstraints(index));
      }
      trailingChildWithLayout = child;
      assert(child != null);
      final SliverMultiBoxAdaptorParentData childParentData = child.parentData;
      assert(childParentData.index == index);
      childParentData.layoutOffset =
          _extentDelegate.layoutOffset(childParentData.index);
    }

    final int lastIndex = indexOf(lastChild);
    final double leadingScrollOffset = _extentDelegate.layoutOffset(firstIndex);
    final double trailingScrollOffset =
        _extentDelegate.layoutOffset(lastIndex + 1);

    assert(firstIndex == 0 ||
        childScrollOffset(firstChild) - scrollOffset <=
            precisionErrorTolerance);
    assert(debugAssertChildListIsNonEmptyAndContiguous());
    assert(indexOf(firstChild) == firstIndex);
    assert(targetLastIndex == null || lastIndex <= targetLastIndex);

    estimatedMaxScrollOffset = math.min(
      estimatedMaxScrollOffset,
      estimateMaxScrollOffset(
        constraints,
        firstIndex: firstIndex,
        lastIndex: lastIndex,
        leadingScrollOffset: leadingScrollOffset,
        trailingScrollOffset: trailingScrollOffset,
      ),
    );

    final double paintExtent = calculatePaintOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    final double targetEndScrollOffsetForPaint =
        constraints.scrollOffset + constraints.remainingPaintExtent;
    final int targetLastIndexForPaint = targetEndScrollOffsetForPaint.isFinite
        ? _extentDelegate
            .maxChildIndexForScrollOffset(targetEndScrollOffsetForPaint)
        : null;
    geometry = SliverGeometry(
      scrollExtent: estimatedMaxScrollOffset,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: estimatedMaxScrollOffset,
      // Conservative to avoid flickering away the clip during scroll.
      hasVisualOverflow: (targetLastIndexForPaint != null &&
              lastIndex >= targetLastIndexForPaint) ||
          constraints.scrollOffset > 0.0,
    );

    // We may have started the layout while scrolled to the end, which would not
    // expose a new child.
    if (estimatedMaxScrollOffset == trailingScrollOffset) {
      childManager.setDidUnderflow(true);
    }
    childManager.didFinishLayout();
  }
}

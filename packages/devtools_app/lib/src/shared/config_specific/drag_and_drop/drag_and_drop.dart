// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../primitives/utils.dart';
import '_drag_and_drop_desktop.dart'
    if (dart.library.js_interop) '_drag_and_drop_web.dart';

abstract class DragAndDropManager {
  factory DragAndDropManager(int viewId) => createDragAndDropManager(viewId);

  DragAndDropManager.impl(int viewId) : _viewId = viewId {
    init();
  }

  static DragAndDropManager getInstance(int viewId) {
    return _instances.putIfAbsent(viewId, () => DragAndDropManager(viewId));
  }

  static final _instances = <int, DragAndDropManager>{};
  int get viewId => _viewId;
  final int _viewId;

  final _dragAndDropStates = <DragAndDropState>{};

  DragAndDropState? activeState;

  /// The method is abstract, because we want to force descendants to define it.
  ///
  /// The method is called in [impl], so any initialization the subclasses need,
  /// like initializing listeners, should happen ahead of time in this method.
  void init();

  @mustCallSuper
  void dispose() {
    _dragAndDropStates.clear();
  }

  void registerDragAndDrop(DragAndDropState state) {
    _dragAndDropStates.add(state);
  }

  void unregisterDragAndDrop(DragAndDropState state) {
    _dragAndDropStates.remove(state);
  }

  void dragOver(double x, double y) {
    hitTestAndUpdateActiveId(x, y);
    activeState?.dragOver();
  }

  void dragLeave() {
    activeState?.dragLeave();
  }

  void drop() {
    activeState?.drop();
  }

  /// Performs a hit test to find the active [DragAndDrop] widget at the (x, y)
  /// coordinates, and updates the active state for the previously active and
  /// newly active [DragAndDrop] widgets accordingly.
  void hitTestAndUpdateActiveId(double x, double y) {
    final hitTestResult = HitTestResult();
    RendererBinding.instance
        .hitTestInView(hitTestResult, Offset(x, y), _viewId);

    // Starting at bottom of [hitTestResult.path], look for the first
    // [DragAndDrop] widget. This widget will be marked by a [RenderMetaData]
    // target with [DragAndDropMetaData] metaData that contains the widget's
    // [DragAndDropState].
    for (final result in hitTestResult.path) {
      final target = result.target;
      if (target is RenderMetaData) {
        final metaData = target.metaData;
        // The first [DragAndDropMetaData] we find will be for the active
        // [DragAndDrop] widget.
        if (metaData is DragAndDropMetaData) {
          final newActiveState = metaData.state;
          // Activate the new state and deactivate the previously active state.

          final previousActiveState = activeState;
          previousActiveState?.setIsActive(false);
          activeState = newActiveState;
          activeState!.setIsActive(true);
          return;
        }
      }
    }
  }
}

class DragAndDrop extends StatefulWidget {
  const DragAndDrop({
    super.key,
    required this.child,
    this.handleDrop,
  });

  /// Callback to handle parsed data from drag and drop.
  ///
  /// The current implementation expects data in json format.
  final DevToolsJsonFileHandler? handleDrop;

  final Widget child;

  @override
  State<DragAndDrop> createState() => DragAndDropState();
}

class DragAndDropState extends State<DragAndDrop> {
  final _dragging = ValueNotifier<bool>(false);
  DragAndDropManager? _dragAndDropManager;

  bool _isActive = false;

  void _refreshDragAndDropManager(int viewId) {
    if (_dragAndDropManager != null) {
      final oldViewId = _dragAndDropManager!.viewId;

      // Already registered to the right drag and drop manager, so do nothing.
      if (oldViewId == viewId) return;

      _dragAndDropManager?.unregisterDragAndDrop(this);
      _dragAndDropManager = null;
    }

    _dragAndDropManager = DragAndDropManager.getInstance(viewId);
    _dragAndDropManager!.registerDragAndDrop(this);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _dragAndDropManager?.unregisterDragAndDrop(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Each time the widget is rebuilt it may be in a a new view. So the
    // dragAndDropManager is refreshed to ensure that we are registered in the
    // right context.
    _refreshDragAndDropManager(View.of(context).viewId);
    return MetaData(
      metaData: DragAndDropMetaData(state: this),
      child: widget.handleDrop != null
          ? ValueListenableBuilder<bool>(
              valueListenable: _dragging,
              builder: (context, dragging, _) {
                // TODO(kenz): use AnimatedOpacity instead.
                return Opacity(
                  opacity: dragging ? 0.5 : 1.0,
                  child: widget.child,
                );
              },
            )
          : widget.child,
    );
  }

  void dragOver() {
    _dragging.value = _isActive;
  }

  void dragLeave() {
    _dragEnd();
  }

  void drop() {
    _dragEnd();
  }

  void setIsActive(bool active) {
    _isActive = active;
    if (!_isActive) {
      _dragEnd();
    }
  }

  void _dragEnd() {
    _dragging.value = false;
  }
}

/// MetaData for widgets related to drag and drop functionality ([DragAndDrop],
/// [DragAndDropEventAbsorber]).
///
/// Drag and drop widgets will contain a [MetaData] widget with the `metaData`
/// field set to an instance of this class. [value] must be a unique identifier
/// for [DragAndDrop] widgets.
class DragAndDropMetaData {
  const DragAndDropMetaData({required this.state});

  final DragAndDropState state;
}

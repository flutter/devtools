// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../notifications.dart';
import '../../utils.dart';
import '_drag_and_drop_stub.dart'
    if (dart.library.html) '_drag_and_drop_web.dart'
    if (dart.library.io) '_drag_and_drop_desktop.dart';

abstract class DragAndDropManager {
  factory DragAndDropManager() => createDragAndDropManager();

  DragAndDropManager.impl() {
    init();
  }

  static DragAndDropManager get instance => _instance ?? DragAndDropManager();

  static DragAndDropManager _instance;

  final _dragAndDropStates = <DragAndDropState>{};

  DragAndDropState activeState;

  @mustCallSuper
  void init() {
    _instance = this;
  }

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
    RendererBinding.instance.hitTest(hitTestResult, Offset(x, y));

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
          if (newActiveState != null) {
            final previousActiveState = activeState;
            previousActiveState?.activate(false);
            activeState = newActiveState;
            activeState.activate(true);
            return;
          }
        }
      }
    }
  }
}

class DragAndDrop extends StatefulWidget {
  const DragAndDrop({
    @required this.child,
    this.handleDrop,
  });

  /// Callback to handle parsed data from drag and drop.
  ///
  /// The current implementation expects data in json format.
  final DevToolsJsonFileHandler handleDrop;

  final Widget child;

  @override
  State<DragAndDrop> createState() => DragAndDropState();
}

class DragAndDropState extends State<DragAndDrop> {
  final _dragging = ValueNotifier<bool>(false);

  NotificationsState notifications;

  bool _isActive;

  @override
  void initState() {
    super.initState();
    DragAndDropManager.instance.registerDragAndDrop(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    notifications = Notifications.of(context);
  }

  @override
  void dispose() {
    DragAndDropManager.instance.unregisterDragAndDrop(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: DragAndDropMetaData(state: this),
      child: widget.handleDrop != null
          ? ValueListenableBuilder(
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
    _dragging.value = _isActive ?? false;
  }

  void dragLeave() {
    _dragEnd();
  }

  void drop() {
    _dragEnd();
  }

  void activate(bool active) {
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
  const DragAndDropMetaData({@required this.state});

  final DragAndDropState state;
}

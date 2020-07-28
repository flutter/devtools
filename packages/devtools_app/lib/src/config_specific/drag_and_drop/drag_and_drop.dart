// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../notifications.dart';
import '_drag_and_drop_stub.dart'
    if (dart.library.html) '_drag_and_drop_web.dart'
    if (dart.library.io) '_drag_and_drop_desktop.dart';

abstract class DragAndDropManager {
  factory DragAndDropManager({@required NotificationsState notifications}) {
    final manager = createDragAndDropManager(notifications: notifications);
    manager.init();
    return manager;
  }

  DragAndDropManager.impl({@required this.notifications});

  final NotificationsState notifications;

  final _statesById = <String, DragAndDropState>{};

  DragAndDropState activeState;

  void init();

  @mustCallSuper
  void dispose() {
    _statesById.clear();
  }

  void registerDragAndDrop(String id, DragAndDropState state) {
    _statesById[id] = state;
  }

  void unregisterDragAndDrop(String id) {
    _statesById.remove(id);
  }

  void dragOver(double x, double y) {
    hitTestAndUpdateActiveId(x, y);
    for (final state in _statesById.values) {
      state.dragOver();
    }
  }

  void dragLeave() {
    for (final state in _statesById.values) {
      state.dragLeave();
    }
  }

  void drop() {
    for (final state in _statesById.values) {
      state.drop();
    }
  }

  /// Performs a hit test to find the id for the active [DragAndDrop] widget at
  /// the (x, y) coordinates, and updates the active state for all [DragAndDrop]
  /// widgets accordingly.
  void hitTestAndUpdateActiveId(double x, double y) {
    final hitTestResult = HitTestResult();
    RendererBinding.instance.hitTest(hitTestResult, Offset(x, y));

    // Starting at bottom of [hitTestResult.path], look for [DragAndDrop] or
    // [DragAndDropEventAbsorber] widgets. These widgets will be marked by a
    // [RenderMetaData] target with [DragAndDropMetaData] metaData.
    for (final result in hitTestResult.path) {
      if (result.target is RenderMetaData) {
        final target = result.target as RenderMetaData;
        // The first [DragAndDropMetaData] we find will either be for the active
        // [DragAndDrop] widget or for a [DragAndDropEventAbsorber] widget. We
        // should return if we find either.
        if (target.metaData is DragAndDropMetaData) {
          final metaData = target.metaData as DragAndDropMetaData;

          // Deactivate all drag and drop states if we find
          // [_dragAndDropEventAbsorberId].
          if (metaData.value == _dragAndDropEventAbsorberId) {
            for (final state in _statesById.values) {
              state.activate(false);
            }
            return;
          }

          // Otherwise, activate the first drag and drop state we found and
          // deactivate all others.
          final activeDragAndDropState = _statesById[target.metaData.value];
          if (activeDragAndDropState != null) {
            for (final state in _statesById.values) {
              activeState = activeDragAndDropState;
              state.activate(state == activeDragAndDropState);
            }
            return;
          }
        }
      }
    }
  }
}

class DragAndDrop extends StatefulWidget {
  const DragAndDrop({
    @required this.id,
    @required this.manager,
    @required this.handleDrop,
    @required this.child,
  });

  final String id;

  /// Callback to handle parsed data from drag and drop.
  ///
  /// The current implementation expects data in json format.
  final void Function(Map<String, dynamic> data) handleDrop;

  final DragAndDropManager manager;

  final Widget child;

  @override
  State<DragAndDrop> createState() => DragAndDropState();
}

class DragAndDropState extends State<DragAndDrop> {
  final _dragging = ValueNotifier<bool>(false);

  bool _isActive;

  @override
  void initState() {
    super.initState();
    widget.manager.registerDragAndDrop(widget.id, this);
  }

  @override
  void dispose() {
    super.dispose();
    widget.manager.unregisterDragAndDrop(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: DragAndDropMetaData(value: widget.id),
      child: ValueListenableBuilder(
        valueListenable: _dragging,
        builder: (context, dragging, _) {
          // TODO(kenz): use AnimatedOpacity instead.
          return Opacity(
            opacity: dragging ? 0.5 : 1.0,
            child: widget.child,
          );
        },
      ),
    );
  }

  void dragOver() {
    _dragging.value = _isActive ?? false;
  }

  void dragLeave() {
    _dragging.value = false;
  }

  void drop() {
    _dragging.value = false;
  }

  void activate(bool active) {
    _isActive = active;
  }
}

const _dragAndDropEventAbsorberId = 'DragAndDropEventAbsorber';

/// Widget to absorb drag and drop events.
///
/// Wraps [child] in a [MetaData] widget with the `metaData` field set to
/// [_dragAndDropEventAbsorberId]. When [DragAndDropManager] performs hit tests,
/// it will look for [_dragAndDropEventAbsorberId] as a mark that drag and drop
/// event propagation should stop. Ancestor [DragAndDrop] widgets that are
/// present in the hit test will not be activated and therefore will not
/// receive drag and drop events.
class DragAndDropEventAbsorber extends StatelessWidget {
  const DragAndDropEventAbsorber({@required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: const DragAndDropMetaData(value: _dragAndDropEventAbsorberId),
      child: child,
    );
  }
}

/// MetaData for widgets related to drag and drop functionality ([DragAndDrop],
/// [DragAndDropEventAbsorber]).
///
/// Drag and drop widgets will contain a [MetaData] widget with the `metaData`
/// field set to an instance of this class. [value] must be a unique identifier
/// for [DragAndDrop] widgets.
class DragAndDropMetaData {
  const DragAndDropMetaData({@required this.value});

  final String value;
}

/// Provider widget for [DragAndDropManager].
///
/// We need this widget because it is a direct child of [Notifications] and we
/// need to instantiate [DragAndDropManager] with a [BuildContext] that contains
/// a [Notificaitons] widget.
class DragAndDropManagerProvider extends StatelessWidget {
  const DragAndDropManagerProvider({@required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Provider<DragAndDropManager>(
      create: (_) =>
          DragAndDropManager(notifications: Notifications.of(context)),
      child: child,
    );
  }
}

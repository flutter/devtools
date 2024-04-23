// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// This file was originally forked from package:flutter_widgets. Note that the
// source may diverge over time.

/// Sets up a collection of scroll controllers that mirror their movements to
/// each other.
///
/// Controllers are added and returned via [addAndGet]. The initial offset
/// of the newly created controller is synced to the current offset.
/// Controllers must be `dispose`d when no longer in use to prevent memory
/// leaks and performance degradation.
///
/// If controllers are disposed over the course of the lifetime of this
/// object the corresponding scrollables should be given unique keys.
/// Without the keys, Flutter may reuse a controller after it has been disposed,
/// which can cause the controller offsets to fall out of sync.
class LinkedScrollControllerGroup {
  LinkedScrollControllerGroup() {
    _offsetNotifier = _LinkedScrollControllerGroupOffsetNotifier(this);
  }

  final _allControllers = <_LinkedScrollController>[];

  ChangeNotifier? get offsetNotifier => _offsetNotifier;
  late final _LinkedScrollControllerGroupOffsetNotifier _offsetNotifier;

  bool get hasAttachedControllers => _attachedControllers.isNotEmpty;

  /// The current scroll offset of the group.
  double get offset {
    assert(
      _attachedControllers.isNotEmpty,
      'LinkedScrollControllerGroup does not have any scroll controllers '
      'attached.',
    );
    return _attachedControllers.first.offset;
  }

  /// The current scroll position of the group.
  ScrollPosition get position {
    assert(
      _attachedControllers.isNotEmpty,
      'LinkedScrollControllerGroup does not have any scroll controllers '
      'attached.',
    );
    return _attachedControllers.first.position;
  }

  /// Creates a new controller that is linked to any existing ones.
  ScrollController addAndGet() {
    final initialScrollOffset = _attachedControllers.isEmpty
        ? 0.0
        : _attachedControllers.first.position.pixels;
    final controller =
        _LinkedScrollController(this, initialScrollOffset: initialScrollOffset);
    _allControllers.add(controller);
    controller.addListener(_offsetNotifier.notifyListeners);
    return controller;
  }

  /// Adds a callback that will be called when the value of [offset] changes.
  void addOffsetChangedListener(VoidCallback onChanged) {
    _offsetNotifier.addListener(onChanged);
  }

  /// Removes the specified offset changed listener.
  void removeOffsetChangedListener(VoidCallback listener) {
    _offsetNotifier.removeListener(listener);
  }

  Iterable<_LinkedScrollController> get _attachedControllers =>
      _allControllers.where((controller) => controller.hasClients);

  /// Animates the scroll position of all linked controllers to [offset].
  Future<void> animateTo(
    double offset, {
    required Curve curve,
    required Duration duration,
  }) async {
    // All scroll controllers are already linked with their peers, so we only
    // need to interact with one controller to mirror the interaction with all
    // other controllers.
    if (_attachedControllers.isNotEmpty) {
      await _attachedControllers.first.animateTo(
        offset,
        duration: duration,
        curve: curve,
      );
    }
  }

  /// Jumps the scroll position of all linked controllers to [value].
  void jumpTo(double value) {
    // All scroll controllers are already linked with their peers, so we only
    // need to interact with one controller to mirror the interaction with all
    // other controllers.
    if (_attachedControllers.isNotEmpty) {
      _attachedControllers.first.jumpTo(value);
    }
  }

  /// Resets the scroll position of all linked controllers to 0.
  void resetScroll() {
    jumpTo(0.0);
  }
}

/// This class provides change notification for [LinkedScrollControllerGroup]'s
/// scroll offset.
///
/// This change notifier de-duplicates change events by only firing listeners
/// when the scroll offset of the group has changed.
// TODO(jacobr): create a shorter tye name.
// ignore: prefer-correct-type-name
class _LinkedScrollControllerGroupOffsetNotifier extends ChangeNotifier {
  _LinkedScrollControllerGroupOffsetNotifier(this.controllerGroup);

  final LinkedScrollControllerGroup controllerGroup;

  /// The cached offset for the group.
  ///
  /// This value will be used in determining whether to notify listeners.
  double? _cachedOffset;

  @override
  void notifyListeners() {
    final currentOffset = controllerGroup.offset;
    if (currentOffset != _cachedOffset) {
      _cachedOffset = currentOffset;
      super.notifyListeners();
    }
  }
}

/// A scroll controller that mirrors its movements to a peer, which must also
/// be a [_LinkedScrollController].
class _LinkedScrollController extends ScrollController {
  _LinkedScrollController(
    this._controllers, {
    required super.initialScrollOffset,
  });

  final LinkedScrollControllerGroup _controllers;

  @override
  void dispose() {
    _controllers._allControllers.remove(this);
    super.dispose();
  }

  @override
  void attach(ScrollPosition position) {
    assert(
      position is _LinkedScrollPosition,
      '_LinkedScrollControllers can only be used with'
      ' _LinkedScrollPositions.',
    );
    final _LinkedScrollPosition linkedPosition =
        position as _LinkedScrollPosition;
    assert(
      linkedPosition.owner == this,
      '_LinkedScrollPosition cannot change controllers once created.',
    );
    super.attach(position);
  }

  @override
  _LinkedScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _LinkedScrollPosition(
      this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      oldPosition: oldPosition,
    );
  }

  @override
  _LinkedScrollPosition get position => super.position as _LinkedScrollPosition;

  Iterable<_LinkedScrollController> get _allPeersWithClients =>
      _controllers._attachedControllers.where((peer) => peer != this);

  bool get canLinkWithPeers => _allPeersWithClients.isNotEmpty;

  Iterable<_LinkedScrollActivity> linkWithPeers(_LinkedScrollPosition driver) {
    assert(canLinkWithPeers);
    return _allPeersWithClients
        .map((peer) => peer.link(driver))
        .expand((e) => e);
  }

  Iterable<_LinkedScrollActivity> link(_LinkedScrollPosition driver) {
    assert(hasClients);
    final activities = <_LinkedScrollActivity>[];
    for (ScrollPosition position in positions) {
      activities.add((position as _LinkedScrollPosition).link(driver));
    }
    return activities;
  }
}

// Implementation details: Whenever position.setPixels or position.forcePixels
// is called on a _LinkedScrollPosition (which may happen programmatically, or
// as a result of a user action),  the _LinkedScrollPosition creates a
// _LinkedScrollActivity for each linked position and uses it to move to or jump
// to the appropriate offset.
//
// When a new activity begins, the set of peer activities is cleared.
class _LinkedScrollPosition extends ScrollPositionWithSingleContext {
  _LinkedScrollPosition(
    this.owner, {
    required super.physics,
    required super.context,
    super.initialPixels = null,
    super.oldPosition,
  });

  final _LinkedScrollController owner;

  final Set<_LinkedScrollActivity> _peerActivities = <_LinkedScrollActivity>{};

  // We override hold to propagate it to all peer controllers.
  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    for (final controller in owner._allPeersWithClients) {
      controller.position._holdInternal();
    }
    return super.hold(holdCancelCallback);
  }

  // Calls hold without propagating to peers.
  void _holdInternal() {
    super.hold(() {});
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity == null) {
      return;
    }
    for (var activity in _peerActivities) {
      activity.unlink(this);
    }

    _peerActivities.clear();

    super.beginActivity(newActivity);
  }

  @override
  double setPixels(double newPixels) {
    if (newPixels == pixels) {
      return 0.0;
    }
    updateUserScrollDirection(
      newPixels - pixels > 0.0
          ? ScrollDirection.forward
          : ScrollDirection.reverse,
    );

    if (owner.canLinkWithPeers) {
      _peerActivities.addAll(owner.linkWithPeers(this));
      for (var activity in _peerActivities) {
        activity.moveTo(newPixels);
      }
    }

    return setPixelsInternal(newPixels);
  }

  double setPixelsInternal(double newPixels) {
    return super.setPixels(newPixels);
  }

  @override
  void forcePixels(double value) {
    if (value == pixels) {
      return;
    }
    updateUserScrollDirection(
      value - pixels > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );

    if (owner.canLinkWithPeers) {
      _peerActivities.addAll(owner.linkWithPeers(this));
      for (var activity in _peerActivities) {
        activity.jumpTo(value);
      }
    }

    forcePixelsInternal(value);
  }

  void forcePixelsInternal(double value) {
    super.forcePixels(value);
  }

  _LinkedScrollActivity link(_LinkedScrollPosition driver) {
    if (this.activity is! _LinkedScrollActivity) {
      beginActivity(_LinkedScrollActivity(this));
    }
    final _LinkedScrollActivity activity =
        this.activity as _LinkedScrollActivity;
    activity.link(driver);
    return activity;
  }

  void unlink(_LinkedScrollActivity activity) {
    _peerActivities.remove(activity);
  }

  // We override this method to make it public (overridden method is protected)
  @override
  void updateUserScrollDirection(ScrollDirection value) {
    super.updateUserScrollDirection(value);
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('owner: $owner');
  }
}

class _LinkedScrollActivity extends ScrollActivity {
  _LinkedScrollActivity(_LinkedScrollPosition super.delegate);

  @override
  _LinkedScrollPosition get delegate => super.delegate as _LinkedScrollPosition;

  final Set<_LinkedScrollPosition> drivers = <_LinkedScrollPosition>{};

  void link(_LinkedScrollPosition driver) {
    drivers.add(driver);
  }

  void unlink(_LinkedScrollPosition driver) {
    drivers.remove(driver);
    if (drivers.isEmpty) {
      delegate.goIdle();
    }
  }

  @override
  bool get shouldIgnorePointer => true;

  @override
  bool get isScrolling => true;

  // _LinkedScrollActivity is not self-driven but moved by calls to the [moveTo]
  // method.
  @override
  double get velocity => 0.0;

  void moveTo(double newPixels) {
    _updateUserScrollDirection();
    delegate.setPixelsInternal(newPixels);
  }

  void jumpTo(double newPixels) {
    _updateUserScrollDirection();
    delegate.forcePixelsInternal(newPixels);
  }

  void _updateUserScrollDirection() {
    assert(drivers.isNotEmpty);
    ScrollDirection? commonDirection;
    for (var driver in drivers) {
      commonDirection ??= driver.userScrollDirection;
      if (driver.userScrollDirection != commonDirection) {
        commonDirection = ScrollDirection.idle;
      }
    }
    delegate.updateUserScrollDirection(commonDirection!);
  }

  @override
  void dispose() {
    for (var driver in drivers) {
      driver.unlink(this);
    }
    super.dispose();
  }
}

// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

/// Provides functionality to simplify listening to streams and ValueNotifiers.
///
/// See also:
/// * [AutoDisposeControllerMixin] which integrates this functionality
///   with [DisposableController] objects.
/// * [AutoDisposeMixin], which integrates this functionality with [State]
///   objects.
class Disposer {
  final List<StreamSubscription> _subscriptions = [];

  final List<Listenable> _listenables = [];
  final List<VoidCallback> _listeners = [];

  /// Track a stream subscription to be automatically cancelled on dispose.
  void autoDispose(StreamSubscription subscription) {
    if (subscription == null) return;
    _subscriptions.add(subscription);
  }

  /// Add a listener to a Listenable object that is automatically removed when
  /// cancel is called.
  void addAutoDisposeListener(Listenable listenable, [VoidCallback listener]) {
    if (listenable == null || listener == null) return;
    _listenables.add(listenable);
    _listeners.add(listener);
    listenable.addListener(listener);
  }

  /// Cancel all listeners added & stream subscriptions.
  ///
  /// It is fine to call this method and then add additional listeners.
  void cancel() {
    for (StreamSubscription subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    assert(_listenables.length == _listeners.length);
    for (int i = 0; i < _listenables.length; ++i) {
      _listenables[i].removeListener(_listeners[i]);
    }
    _listenables.clear();
    _listeners.clear();
  }
}

/// Base class for controllers that need to manage their lifecycle.
abstract class DisposableController {
  @mustCallSuper
  void dispose() {}
}

/// Mixin to simplifying managing the lifetime of listeners used by a
/// [DisposableController].
///
/// This mixin works by delegating to a [Disposer]. It implements all of
/// [Disposer]'s interface.
///
/// See also:
/// * [AutoDisposeMixin], which provides the same functionality for a
///   [StatefulWidget].
mixin AutoDisposeControllerMixin on DisposableController implements Disposer {
  final Disposer _delegate = Disposer();

  @override
  void dispose() {
    cancel();
    super.dispose();
  }

  @override
  void addAutoDisposeListener(Listenable listenable, [VoidCallback listener]) {
    _delegate.addAutoDisposeListener(listenable, listener);
  }

  @override
  void autoDispose(StreamSubscription subscription) {
    _delegate.autoDispose(subscription);
  }

  @override
  void cancel() {
    _delegate.cancel();
  }
}

// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Provides functionality to simplify listening to streams and ValueNotifiers,
/// and disposing FocusNodes.
///
/// See also:
/// * [AutoDisposeControllerMixin] which integrates this functionality
///   with [DisposableController] objects.
/// * [AutoDisposeMixin], which integrates this functionality with [State]
///   objects.
class Disposer {
  final List<StreamSubscription> _subscriptions = [];
  final List<FocusNode> _focusNodes = [];

  final List<Listenable> _listenables = [];
  final List<VoidCallback> _listeners = [];

  /// Track a stream subscription to be automatically cancelled on dispose.
  void autoDisposeStreamSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Track a focus node that will be automatically disposed on dispose.
  void autoDisposeFocusNode(FocusNode? node) {
    if (node == null) return;
    _focusNodes.add(node);
  }

  /// Add a listener to a Listenable object that is automatically removed when
  /// cancel is called.
  void addAutoDisposeListener(
    Listenable? listenable, [
    VoidCallback? listener,
  ]) {
    if (listenable == null || listener == null) return;
    _listenables.add(listenable);
    _listeners.add(listener);
    listenable.addListener(listener);
  }

  /// Cancel all stream subscriptions added.
  ///
  /// It is fine to call this method and then add additional subscriptions.
  void cancelStreamSubscriptions() {
    for (StreamSubscription subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Cancel all listeners added.
  ///
  /// It is fine to call this method and then add additional listeners.
  void cancelListeners() {
    assert(_listenables.length == _listeners.length);
    for (int i = 0; i < _listenables.length; ++i) {
      _listenables[i].removeListener(_listeners[i]);
    }
    _listenables.clear();
    _listeners.clear();
  }

  /// Cancel all focus nodes added.
  ///
  /// It is fine to call this method and then add additional focus nodes.
  void cancelFocusNodes() {
    for (FocusNode focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _focusNodes.clear();
  }

  /// Assign a [callback] to [trigger], such that the [callback] will run
  /// once when [trigger] is equal to [readyWhen].
  ///
  /// When calling [callOnceWhenReady] :
  ///     - If [trigger] is equal to [readyWhen], then the [callback] will be immediately triggered
  ///     - Otherwise, the [callback] will be triggered when [trigger] changes to equal [readyWhen]
  ///
  /// Any listeners set by [callOnceWhenReady] will auto dispose, or be removed after the callback is run.
  void callOnceWhenReady<T>({
    required VoidCallback callback,
    required ValueListenable<T> trigger,
    required bool Function(T triggerValue) readyWhen,
  }) {
    if (readyWhen(trigger.value)) {
      callback();
    } else {
      // do the stuff to add the listener and remove it when appropriate
      VoidCallback? earlyDisposeCallback;
      earlyDisposeCallback = () {
        if (readyWhen(trigger.value)) {
          callback();
          trigger.removeListener(earlyDisposeCallback!);
        }
      };
      addAutoDisposeListener(trigger, earlyDisposeCallback);
    }
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
    cancelStreamSubscriptions();
    cancelListeners();
    cancelFocusNodes();
    super.dispose();
  }

  @override
  void addAutoDisposeListener(
    Listenable? listenable, [
    VoidCallback? listener,
  ]) {
    _delegate.addAutoDisposeListener(listenable, listener);
  }

  @override
  void autoDisposeStreamSubscription(StreamSubscription subscription) {
    _delegate.autoDisposeStreamSubscription(subscription);
  }

  @override
  void autoDisposeFocusNode(FocusNode? node) {
    _delegate.autoDisposeFocusNode(node);
  }

  @override
  void cancelStreamSubscriptions() {
    _delegate.cancelStreamSubscriptions();
  }

  @override
  void cancelListeners() {
    _delegate.cancelListeners();
  }

  @override
  void cancelFocusNodes() {
    _delegate.cancelFocusNodes();
  }

  @override
  void callOnceWhenReady<T>({
    required VoidCallback callback,
    required ValueListenable<T> trigger,
    required bool Function(T triggerValue) readyWhen,
  }) {
    _delegate.callOnceWhenReady(
      callback: callback,
      trigger: trigger,
      readyWhen: readyWhen,
    );
  }
}

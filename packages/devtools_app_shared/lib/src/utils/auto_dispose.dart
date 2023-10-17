// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Mixin to simplifying managing the lifetime of listeners used by a
/// [StatefulWidget].
///
/// This mixin works by delegating to a [DisposerMixin]. It implements all of
/// [DisposerMixin]'s interface.
///
/// See also:
/// * [AutoDisposeControllerMixin], which provides the same functionality for
///   controller classes.
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T>
    implements DisposerMixin {
  final _delegate = Disposer();

  @override
  @visibleForTesting
  List<Listenable> get listenables => _delegate.listenables;
  @override
  @visibleForTesting
  List<VoidCallback> get listeners => _delegate.listeners;

  @override
  void dispose() {
    cancelStreamSubscriptions();
    cancelListeners();
    cancelFocusNodes();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Add a listener to a Listenable object that is automatically removed on
  /// the object disposal or when cancel is called.
  ///
  /// If listener is not provided, setState will be invoked.
  @override
  void addAutoDisposeListener(
    Listenable? listenable, [
    VoidCallback? listener,
    String? id,
  ]) {
    _delegate.addAutoDisposeListener(listenable, listener ?? _refresh, id);
  }

  @override
  // ignore: avoid_shadowing_type_parameters, false positive
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
  void cancelListeners({List<String> excludeIds = const <String>[]}) {
    _delegate.cancelListeners(excludeIds: excludeIds);
  }

  @override
  void cancelListener(VoidCallback? listener) {
    _delegate.cancelListener(listener);
  }

  @override
  void cancelFocusNodes() {
    _delegate.cancelFocusNodes();
  }
}

/// Provides functionality to simplify listening to streams and ValueNotifiers,
/// and disposing FocusNodes.
///
/// See also:
/// * [AutoDisposeControllerMixin] which integrates this functionality
///   with [DisposableController] objects.
/// * [AutoDisposeMixin], which integrates this functionality with [State]
///   objects.
mixin DisposerMixin {
  final List<StreamSubscription> _subscriptions = [];
  final List<FocusNode> _focusNodes = [];

  @protected
  @visibleForTesting
  List<Listenable> get listenables => _listenables;

  /// Not using VoidCallback because of
  /// https://github.com/dart-lang/mockito/issues/579
  @protected
  @visibleForTesting
  List<void Function()> get listeners => _listeners;

  final List<Listenable> _listenables = [];
  final List<VoidCallback> _listeners = [];

  /// An [Expando] that tracks listener ids when [addAutoDisposeListener] is
  /// called with a non-null [id] parameter.
  final _listenerIdExpando = Expando<String>();

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
    String? id,
  ]) {
    if (listenable == null || listener == null) return;
    _listenables.add(listenable);
    _listeners.add(listener);
    listenable.addListener(listener);

    if (id != null) {
      _listenerIdExpando[listener] = id;
    }
  }

  /// Cancel all stream subscriptions added.
  ///
  /// It is fine to call this method and then add additional subscriptions.
  void cancelStreamSubscriptions() {
    for (StreamSubscription subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  /// Cancel all listeners added.
  ///
  /// It is fine to call this method and then add additional listeners.
  ///
  /// If [excludeIds] is non-empty, any listeners that have an associated id
  /// from [_listenersById] will not be cancelled.
  void cancelListeners({List<String> excludeIds = const <String>[]}) {
    assert(_listenables.length == _listeners.length);
    final skipCancelIndices = <int>[];
    for (int i = 0; i < _listenables.length; ++i) {
      final listener = _listeners[i];
      final listenerId = _listenerIdExpando[listener];
      if (listenerId != null && excludeIds.contains(listenerId)) {
        skipCancelIndices.add(i);
        continue;
      }

      _listenables[i].removeListener(listener);
    }

    _listenables.removeAllExceptIndices(skipCancelIndices);
    _listeners.removeAllExceptIndices(skipCancelIndices);
  }

  /// Cancels a single listener, if present.
  void cancelListener(VoidCallback? listener) {
    if (listener == null) return;

    assert(_listenables.length == _listeners.length);
    final foundIndex =
        _listeners.indexWhere((currentListener) => currentListener == listener);
    if (foundIndex == -1) return;
    _listenables[foundIndex].removeListener(_listeners[foundIndex]);
    _listenables.removeAt(foundIndex);
    _listeners.removeAt(foundIndex);
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

  /// Runs [callback] when [trigger]'s value satisfies the [readyWhen] function.
  ///
  /// When calling [callOnceWhenReady] :
  ///     - If [trigger]'s value satisfies [readyWhen], then the [callback] will
  ///       be immediately triggered.
  ///     - Otherwise, the [callback] will be triggered when [trigger]'s value
  ///       changes to equal [readyWhen].
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
      VoidCallback? triggerListener;
      triggerListener = () {
        if (readyWhen(trigger.value)) {
          callback();
          trigger.removeListener(triggerListener!);

          _listenables.remove(trigger);
          _listeners.remove(triggerListener);
        }
      };
      addAutoDisposeListener(trigger, triggerListener);
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
/// This mixin works by delegating to a [DisposerMixin]. It implements all of
/// [DisposerMixin]'s interface.
///
/// See also:
/// * [AutoDisposeMixin], which provides the same functionality for a
///   [StatefulWidget].
mixin AutoDisposeControllerMixin on DisposableController
    implements DisposerMixin {
  final _delegate = Disposer();

  @override
  @visibleForTesting
  List<Listenable> get listenables => _delegate.listenables;

  /// Not using VoidCallback because of
  /// https://github.com/dart-lang/mockito/issues/579
  @override
  @visibleForTesting
  List<void Function()> get listeners => _delegate.listeners;

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
    String? id,
  ]) {
    _delegate.addAutoDisposeListener(listenable, listener, id);
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
  void cancelListeners({List<String> excludeIds = const <String>[]}) {
    _delegate.cancelListeners();
  }

  @override
  void cancelListener(VoidCallback? listener) {
    _delegate.cancelListener(listener);
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

@visibleForTesting
class Disposer with DisposerMixin {}

extension _AutoDisposeListExtension<T> on List<T> {
  /// Reduces the list content to include only elements at [indices].
  ///
  /// If any index in [indices] is out of range, an exception will be thrown.
  void removeAllExceptIndices(List<int> indices) {
    final tmp = [
      for (int index in indices) this[index],
    ];
    clear();
    addAll(tmp);
  }
}

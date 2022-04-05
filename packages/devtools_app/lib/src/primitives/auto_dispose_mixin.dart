// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auto_dispose.dart';

/// Mixin to simplifying managing the lifetime of listeners used by a
/// [StatefulWidget].
///
/// This mixin works by delegating to a [Disposer]. It implements all of
/// [Disposer]'s interface.
///
/// See also:
/// * [AutoDisposeControllerMixin], which provides the same functionality for
///   controller classes.
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T>
    implements Disposer {
  final Disposer _delegate = Disposer();

  @override
  void dispose() {
    cancelStreamSubscriptions();
    cancelListeners();
    cancelFocusNodes();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  void addAutoDisposeListener(
    Listenable? listenable, [
    VoidCallback? listener,
  ]) {
    _delegate.addAutoDisposeListener(listenable, listener ?? _refresh);
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
}

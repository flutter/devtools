// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

/// An event type for use with [MessageBus].
class BusEvent {
  BusEvent(this.type, {this.data});

  final String type;
  final Object? data;

  @override
  String toString() => type;
}

/// A message bus class. Clients can listen for classes of events, optionally
/// filtered by a string type. This can be used to decouple events sources and
/// event listeners.
class MessageBus {
  MessageBus() {
    _controller = StreamController<BusEvent>.broadcast();
  }

  late StreamController<BusEvent> _controller;

  /// Listen for events on the event bus. Clients can pass in an optional [type],
  /// which filters the events to only those specific ones.
  Stream<BusEvent> onEvent({String? type}) {
    return type == null
        ? _controller.stream
        : _controller.stream.where((BusEvent event) => event.type == type);
  }

  /// Add an event to the event bus.
  void addEvent(BusEvent event) {
    _controller.add(event);
  }

  /// Close (destroy) this [MessageBus]. This is generally not used outside of a
  /// testing context. All stream listeners will be closed and the bus will not
  /// fire any more events.
  @visibleForTesting
  void close() {
    unawaited(_controller.close());
  }
}

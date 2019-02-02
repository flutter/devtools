// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js' as js;

typedef Convert3Arg<T> = T Function(dynamic arg1, dynamic arg2, dynamic arg3);

class EventListener3Arg<T> {
  EventListener3Arg(this._proxy, this._name, {this.cvtEvent});

  final js.JsObject _proxy;
  final String _name;
  final Convert3Arg<T> cvtEvent;

  StreamController<T> _controller;
  js.JsFunction _callback;

  Stream<T> get stream {
    // ignore: prefer_conditional_assignment
    if (_controller == null) {
      _controller = new StreamController.broadcast(
        onListen: () {
          _callback = _proxy.callMethod('on', [
            _name,
            (obj, arg1, arg2, arg3) {
              _controller
                  .add(cvtEvent == null ? arg1 : cvtEvent(arg1, arg2, arg3));
            }
          ]);
        },
        onCancel: () {
          _proxy.callMethod('off', [_name, _callback]);
          _callback = null;
        },
        sync: true,
      );
    }
    return _controller.stream;
  }

  Future dispose() {
    if (_controller == null) return new Future.value();
    return _controller.close();
  }
}

// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:developer';

/// This class will be used from `app_that_uses_foo`.
/// 
/// When [FooController] is initialized in `app_that_uses_foo`, the `initFoo`
/// method will be called to register service extensions.
class FooController {
  FooController() {
    if (!_initialized) {
      initFoo();
    }
  }

  static final _things = <String, String>{
    '1': 'apple',
    '2': 'banana',
  };

  static bool _initialized = false;

  /// In this method, we register a couple service extensions using
  /// [registerExtension] from dart:developer
  /// (see https://api.flutter.dev/flutter/dart-developer/registerExtension.html).
  /// 
  /// The service extensions will be registered in the context of the current
  /// isolate (whatever is the current isolate where `initFoo` is invoked).
  /// 
  /// To see an example of how these service extensions are called from a
  /// DevTools extension, see the [TableOfThings] and [SelectedThing] widgets
  /// from devtools_extensions/example/foo/packages/foo_devtools_extension/lib/src/service_extension_example.dart.
  static void initFoo() {
    registerExtension('ext.foo.getThing', (method, parameters) async {
      final thingId = parameters['id'];
      final thing = _things[thingId] ?? 'unknown thing';
      final response = {
        'id': thingId,
        'value': thing,
      };
      return ServiceExtensionResponse.result(json.encode(response));
    });
    registerExtension('ext.foo.getAllThings', (method, parameters) async {
      return ServiceExtensionResponse.result(json.encode(_things));
    });

    _initialized = true;
  }

  void addThing(int id, String thing) {
    _things['$id'] = thing;
  }

  int get totalThings => _things.length;
}

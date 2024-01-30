// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:developer';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// This class will be used from `app_that_uses_foo`.
///
/// When [FooController] is initialized in `app_that_uses_foo`, the `initFoo`
/// method will be called to register service extensions.
class FooController {
  FooController._() {
    initFoo();
  }

  static FooController get instance => _instance;
  static final _instance = FooController._();

  final things = ValueNotifier<List<String>>(_things);
  static final _things = _sampleThings.sublist(0, 3);

  final favoriteThing = ValueNotifier<String>(_favoriteThing);
  static String _favoriteThing = _sampleThings.first;

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
  ///
  /// Service extensions cannot be called while an isolate is paused. If you
  /// need to fetch data when an isolate is paused, use [EvalOnDartLibrary]
  /// (see devtools_extensions/example/foo/packages/foo_devtools_extension/lib/src/eval_on_dart_library_example.dart).
  void initFoo() {
    if (!_initialized) {
      registerExtension('ext.foo.getThing', (method, parameters) async {
        final thingIndex = int.tryParse(parameters['id'] ?? '0') ?? 0;
        return ServiceExtensionResponse.result(
          json.encode({
            'index': thingIndex,
            'value': _things[thingIndex],
          }),
        );
      });
      registerExtension('ext.foo.getAllThings', (method, parameters) async {
        return ServiceExtensionResponse.result(
          json.encode({'things': _things}),
        );
      });
    }
    _initialized = true;
  }

  /// Adds a thing to the list of [_things].
  ///
  /// This method is called from [FooWidget], which is used in
  /// `app_that_uses_foo`.
  void addThing() {
    final nextIndex = _things.length % _sampleThings.length;
    _things.add(_sampleThings[nextIndex]);
    _update();
  }

  /// Removes a thing from the list of [_things].
  ///
  /// This method is called from [FooWidget], which is used in
  /// `app_that_uses_foo`.
  void removeThing() {
    if (_things.isNotEmpty) {
      _things.removeLast();
      _update();
    }
  }

  /// Selects a random thing from the list of [_things] and assigns it to
  /// [_favoriteThing].
  ///
  /// This method is called from [FooWidget], which is used in
  /// `app_that_uses_foo`.
  void selectRandomFavorite() {
    final randomIndex = Random().nextInt(_things.length);
    _favoriteThing = _things[randomIndex];
    _update();
  }

  void _update() {
    things.value = List.of(_things);
    favoriteThing.value = _favoriteThing;
  }
}

const _sampleThings = [
  'apple',
  'banana',
  'orange',
  'plum',
  'peach',
  'avocado',
  'grapes',
  'broccoli',
  'pear',
  'asparagus',
  'mango',
  'pineapple',
  'guava',
  'squash',
  'pumpkin',
];

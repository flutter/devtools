// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';

class FooBarBaz extends StatelessWidget {
  const FooBarBaz({super.key, this.onFoo, this.onBar, this.onBaz});

  final VoidCallback? onFoo;
  final VoidCallback? onBar;
  final VoidCallback? onBaz;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton(
            onPressed: onFoo,
            child: const Text('Foo'),
          ),
          TextButton(
            onPressed: onBar,
            child: const Text('Bar'),
          ),
          TextButton(
            onPressed: onBaz,
            child: const Text('Baz'),
          ),
        ],
      ),
    );
  }
}

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

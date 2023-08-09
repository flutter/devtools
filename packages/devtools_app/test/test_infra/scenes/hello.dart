// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

/// To run:
/// flutter run -t test/scenes/hello.stager_app.g.dart -d macos
class HelloScene extends Scene {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Card(
        child: Text('Hello, I am $title.'),
      ),
    );
  }

  @override
  Future<void> setUp() async {}

  @override
  String get title => '$runtimeType';
}

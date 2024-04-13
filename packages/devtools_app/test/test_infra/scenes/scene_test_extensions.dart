// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stager/stager.dart';

extension StagerTestExtensions on WidgetTester {
  Future<void> pumpScene(Scene scene) async {
    await runAsync(() async {
      await pumpWidget(
        Builder(
          builder: (BuildContext context) => scene.build(context),
        ),
      );
    });
  }
}

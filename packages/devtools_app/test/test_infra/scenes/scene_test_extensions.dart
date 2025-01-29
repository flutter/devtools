// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stager/stager.dart';

extension StagerTestExtensions on WidgetTester {
  Future<void> pumpScene(Scene scene) async {
    await pumpWidget(
      Builder(builder: (BuildContext context) => scene.build(context)),
    );
  }

  Future<void> pumpSceneAsync(Scene scene) async {
    await runAsync(() async {
      await pumpWidget(
        Builder(builder: (BuildContext context) => scene.build(context)),
      );
    });
  }
}

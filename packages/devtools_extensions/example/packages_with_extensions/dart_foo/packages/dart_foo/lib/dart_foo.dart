// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class DartFoo {
  Future<void> loop() async {
    for (var i = 0; i < 10000; i++) {
      print('Looping from DartFoo.loop(): $i');
      await Future.delayed(const Duration(seconds: 10));
    }
  }
}

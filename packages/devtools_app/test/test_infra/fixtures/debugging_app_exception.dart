// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

void main() {
  print('starting debugging app (exception)');

  void run() {
    Timer(const Duration(milliseconds: 200), () async {
      performAction();

      run();
    });
  }

  run();
}

void performAction() {
  int foo = 1;
  print(foo++);

  try {
    throw StateError('bad state'); // exception
  } catch (e) {
    // ignore
  }
}

// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:async';

void main() {
  print('starting debugging app (exception)');

  void run() {
    Timer(const Duration(milliseconds: 200), () {
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

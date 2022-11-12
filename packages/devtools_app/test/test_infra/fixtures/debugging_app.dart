// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

void main() {
  print('starting debugging app');

  final Cat cat = Cat('Fluffy');

  void run() {
    Timer(const Duration(milliseconds: 100), () {
      cat.performAction();

      run();
    });
  }

  run();
}

class Cat {
  Cat(this.name);

  final String name;

  String get type => 'cat';

  int actionCount = 0;

  void performAction() {
    String actionStr = 'catAction';
    actionStr = actionStr + '!';

    actionCount++; // breakpoint
  }
}

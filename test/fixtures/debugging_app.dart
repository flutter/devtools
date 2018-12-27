// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

void main() {
  print('starting debugging app');

  final Cat cat = new Cat('Fluffy');

  new Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
    cat.performAction();
  });
}

class Cat {
  Cat(this.name);

  final String name;

  String get type => 'cat';

  int actionCount = 0;

  void performAction() {
    actionCount++; //bp1
  }
}

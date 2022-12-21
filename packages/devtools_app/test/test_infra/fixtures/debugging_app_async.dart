// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

void main() {
  print('starting debugging app (async)');

  void run() {
    Timer(const Duration(milliseconds: 100), () async {
      await performAction();

      run();
    });
  }

  run();
}

int actionCount = 0;

Future performAction() async {
  inc(); // breakpoint

  print(actionCount); // step

  inc(); // step

  print(actionCount); // step

  await delay(); // step
}

void inc() {
  actionCount++;
}

Future delay() {
  return Future.delayed(const Duration(milliseconds: 100));
}

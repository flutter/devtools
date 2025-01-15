// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

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

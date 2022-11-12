// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

void simplePrint() {
  print('hello world');
}

noReturnValue() {
  print('hello world');
}

Future<void> asyncPrint() async {
  await Future.delayed(const Duration(seconds: 1));
  print('hello world');
}

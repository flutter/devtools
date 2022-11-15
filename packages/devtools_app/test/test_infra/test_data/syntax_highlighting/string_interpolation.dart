// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

void values() {
  final i = 1;
  final j = 2;

  print('the value of \$i is $i');
  print('the value after \$i is ${i + 1}');
  print('the value of \$i + \$j is ${i + j}');
}

void functions() {
  print('${() {
    return 'Hello';
  }}');
  print('print(${() {
    return 'Hello';
  }()})');
  print('${() => 'Hello'}');
  print('print(${(() => 'Hello')()})');
}

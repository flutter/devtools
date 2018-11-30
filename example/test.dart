// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'test_foo.dart';

void main() {
  int count = foo(9);

  Timer.periodic(new Duration(seconds: 4), (Timer timer) {
    bar(count--);

    if (count == 0) {
      count = foo(9);
    }
  });
}

void bar(int count) {
  final Directory dir = new Directory('.');

  print('$count:00');

  for (FileSystemEntity entity in dir.listSync()) {
    final String name = path.basename(entity.path);
    print('  $name');
  }

  print('');
}

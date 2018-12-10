// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'test_foo.dart';

void main() {
  const Duration delay = Duration(seconds: 4);
  Function work;

  int count = 0;

  work = () {
    bar(count++);

    if (count % 2 == 0) {
      Timer.run(() {
        //throw new StateError('sdfsdf');
      });
    }

    if (count == foo(9)) {
      count = 0;
    }

    new Timer(delay, work);
  };

  new Timer(delay, work);
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

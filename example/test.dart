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
  String description;

  work = () async {
    description = 'items: $count';

    final List<int> numbers = new List.generate(10, (index) => index * index);
    // ignore: unused_local_variable
    final Map<int, String> numberDescriptions =
        new Map.fromIterable(numbers, value: (key) => _toWord(key));

    await bar(count++);

    if (count % 2 == 0) {
      Timer.run(() {
        const int sampleLocal = 123;
        try {
          throw new StateError('sdfsdf: $sampleLocal, $description');
        } catch (e) {
          print(e);
        }
      });
    }

    if (count == foo(9)) {
      count = 0;
    }

    new Timer(delay, work);
  };

  new Timer(delay, work);
}

String _toWord(int key) {
  const Map<int, String> _map = {
    0: 'zero',
    1: 'one',
    2: 'two',
    3: 'three',
    4: 'four',
    5: 'five',
    6: 'six',
    7: 'seven',
    8: 'eight',
    9: 'nine',
  };

  final String desc = key.toString();
  return desc.codeUnits.map((unit) => _map[unit - 48]).join(' ');
}

Future bar(int count) async {
  final Directory dir = new Directory('.');

  await Future.delayed(const Duration(milliseconds: 4));

  print('$count:00');

  await Future.delayed(const Duration(milliseconds: 4));

  for (FileSystemEntity entity in dir.listSync()) {
    final String name = path.basename(entity.path);
    print('  $name');
  }

  print('');
}

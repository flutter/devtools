// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Forces at least one old space GC to happen.
///
/// It is temporary implementation while 'right' way is not possible:
/// https://github.com/dart-lang/sdk/issues/49320
Future<void> forceGC() async {
  _gcValidator = List.filled(100, DateTime.now());
  final ref = WeakReference<Object>(_gcValidator!);
  await _doSomeAllocationsInOldAndNewSpace();
  _gcValidator = null;

  int count = 0;
  while (ref.target != null) {
    count++;
    await _doSomeAllocationsInOldAndNewSpace();
  }
  print('GC happened after $count iterations.');
  _oldSpaceObjects.clear();
}

Object? _gcValidator;
final _oldSpaceObjects = <Object>[];

Future<void> _doSomeAllocationsInOldAndNewSpace() async {
  for (var i = 0; i < 100; i++) {
    await Future.delayed(const Duration(milliseconds: 10));
    final l = List.filled(10000, DateTime.now());
    _oldSpaceObjects.add(l);
    if (_oldSpaceObjects.length > 100) _oldSpaceObjects.removeAt(0);
  }
}

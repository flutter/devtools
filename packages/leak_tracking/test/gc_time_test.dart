// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:leak_tracking/src/_gc_time.dart';

import 'package:test/test.dart';

void main() {
  test('Cycles happen as expected.', () {
    final gcTime = GCTimeLine();
    expect(gcTime.now, 1);
    _registerGCEvents(7, gcTime);
    expect(gcTime.now, 1);
    _registerGCEvents(1, gcTime);
    expect(gcTime.now, 2);
    _registerGCEvents(7, gcTime);
    expect(gcTime.now, 2);
    _registerGCEvents(1, gcTime);
    expect(gcTime.now, 3);
  });
}

void _registerGCEvents(int count, GCTimeLine gcTimeLine) {
  for (var _ in Iterable.generate(count)) {
    gcTimeLine.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
  }
}

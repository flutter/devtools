// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

void foo() {
  Object? a;
  if (1 == 2) {}
  if (1 != 2) {}
  if (1 < 2) {}
  if (1 <= 2) {}
  if (1 > 2) {}
  if (1 >= 2) {}
  var b = 1 < 2 ? 1 / 1 : 2 * 2;
  a ??= b;
  b += 1;
  b -= 1;
  b = b / 2;
  b = b ~/ 2;
  b = b % 2;
  b++;
  b--;
  ++b;
  --b;
  var c = 1 >> 2;
  c >>= 1;
  var d = 1 << 2;
  d <<= 2;
  var e = 1 >>> 2;
  e >>>= 3;
  var f = -b;
  var g = 1 & 2;
  var h = 1 ^ 2;
  var i = ~2;
  var j = 1 & 2;
  j &= 2;
  j ^= 2;
  j |= 2;
  var k = 1 ^ 2;
  var l = 1 | 2;
  var m = !(a == a && false || true);
}

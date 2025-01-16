// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:dart_foo/dart_foo.dart';

// This is a script that uses `package:dart_foo`.
void main() async {
  final dartFoo = DartFoo();
  await dartFoo.loop();
}

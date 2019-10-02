// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/main.dart' as devtools;

// Entry-point in the web directory required to run directly with the
// WebDev package and dart2j instead of using `flutter run -d chrome`.
void main() {
  devtools.main();
}

// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:async';

void main() {
  print('starting empty app');

  // Don't exit until it's indicated we should by the controller.
  Timer(const Duration(days: 1), () {});
}

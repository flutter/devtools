// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

void main() {
  print('starting empty app');

  // Don't exit until it's indicated we should by the controller.
  Timer(const Duration(days: 1), () {});
}

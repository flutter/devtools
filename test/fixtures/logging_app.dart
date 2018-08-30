// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:io';

// Allow a test driver to communicate with this app through the controller.
final Controller controller = new Controller();

void main() {
  log('starting app');
  print('starting app');

  // Don't exit until it's indicated we should by the controller.
  new Timer(const Duration(days: 1), () {});
}

class Controller {
  int count = 0;

  void emitLog() {
    count++;

    print('emitLog called');

    log('emit log $count', name: 'logging');
  }

  void shutdown() {
    log('stopping app');
    print('stopping app');

    exit(0);
  }
}

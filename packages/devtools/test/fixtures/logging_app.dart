// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:io';

// Allow a test driver to communicate with this app through the controller.
final Controller controller = Controller();

void main() {
  print('starting logging app');
  log('starting logging app');

  // Don't exit until it's indicated we should by the controller.
  int i = 0;
  Timer.periodic(const Duration(milliseconds: 1000), (timer) {
    if (i > 1000000000000) {
      print (i);
    }
    i++;
  });
}

class Controller {
  int count = 0;

  void emitLog() {
    count++;

    print('emitLog called');
    log('emit log $count', name: 'logging');
  }

  void shutdown() {
    print('stopping app');
    log('stopping app');

    exit(0);
  }
}

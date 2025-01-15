// Copyright 2018 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:developer';
import 'dart:io';

// Allow a test driver to communicate with this app through the controller.
final controller = Controller();

void main() {
  print('starting logging app');
  log('starting logging app');

  // Don't exit until it's indicated we should by the controller.
  Timer(const Duration(days: 1), () {});
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

// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ATTENTION: If any lines are added to or  deleted from this file then the
// debugger panel integration test will need to be updated with new line numbers
// (the test verifies that breakpoints are hit at specific lines).

import 'dart:async';

import 'package:flutter/material.dart';

// Unused class in the sample application that is a widget.
//
// This is a fairly long description so that we can make sure that scrolling to
// a line works when we are paused at a breakpoint.
class MyOtherWidget extends StatelessWidget {
  const MyOtherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

// Unused class in the sample application that is not a widget.
//
// This is a fairly long description so that we can make sure that scrolling to
// a line works when we are paused at a breakpoint.
class NotAWidget {}

// Used class in the sample application that is not a widget.
//
// This is a class that can be used to periodically call a function at a set
// interval.
//
// This is a fairly long description so that we can make sure that scrolling to
// a line works when we are paused at a breakpoint.
class PeriodicAction {
  PeriodicAction(this._action);

  final void Function() _action;

  void doEvery(Duration interval) {
    Timer.periodic(interval, (_) {
      _action();
    });
  }
}

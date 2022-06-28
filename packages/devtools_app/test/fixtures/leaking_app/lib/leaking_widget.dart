// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'tracked_class.dart';

class MyClass {
  MyTrackedClass? notGCed1 = MyTrackedClass(
      token: 'not-GCed1', child: MyTrackedClass(token: 'not-GCed2'));

  void dispose() {
    notGCed1?.dispose();
  }
}

class LeakingWidget extends StatefulWidget {
  const LeakingWidget({Key? key}) : super(key: key);

  @override
  State<LeakingWidget> createState() => _LeakingWidgetState();
}

class _LeakingWidgetState extends State<LeakingWidget> {
  bool _isCleaned = false;
  MyTrackedClass? _notDisposed = MyTrackedClass(token: 'not-disposed');
  MyTrackedClass? _disposedAndGCed = MyTrackedClass(token: 'disposed-and-GCed');
  // ignore: unnecessary_nullable_for_final_variable_declarations
  final MyClass? _notGCed = MyClass();

  @override
  Widget build(BuildContext context) {
    if (!_isCleaned) {
      if (_notDisposed != null) _notDisposed = null;

      _notGCed?.dispose();

      _disposedAndGCed?.dispose();
      _disposedAndGCed = null;

      _isCleaned = true;

      print('notGCed1: ${identityHashCode(_notGCed!.notGCed1)}');
      print('notGCed2: ${identityHashCode(_notGCed!.notGCed1!.child)}');
      print('parent: ${identityHashCode(_notGCed)}');
    }

    return Column(children: const [
      SizedBox(
        width: 200,
        height: 100,
        child: Text('I am leaking widget'),
      ),
    ]);
  }
}

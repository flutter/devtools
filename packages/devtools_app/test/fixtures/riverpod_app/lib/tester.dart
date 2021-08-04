// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

export 'package:flutter_test/flutter_test.dart';

class _Tester extends WidgetController {
  _Tester() : super(WidgetsBinding.instance!);

  @override
  Future<List<Duration>> handlePointerEventRecord(
    List<PointerEventRecord> records,
  ) {
    return Future.error(UnimplementedError());
  }

  @override
  Future<void> pump([Duration? duration]) {
    binding.renderViewElement!.markNeedsBuild();

    final completer = Completer<void>();
    binding.addPostFrameCallback((timeStamp) => completer.complete());

    return completer.future;
  }

  @override
  Future<int> pumpAndSettle([
    Duration duration = const Duration(milliseconds: 100),
  ]) {
    return Future.error(UnimplementedError());
  }
}

final tester = _Tester();

Future<T> $await<T>(Future<T> future, String id) async {
  try {
    return await future;
  } finally {
    postEvent('future_completed', {'id': id});
  }
}

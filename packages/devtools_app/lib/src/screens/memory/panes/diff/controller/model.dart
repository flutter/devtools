// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

abstract class DiffListItem {
  /// Number, that, if shown in name, should be unique in the list.
  ///
  /// If the number is not shown, it should be 0.
  int get displayNumber;

  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);
}

class InformationListItem extends DiffListItem {
  @override
  int get displayNumber => 0;
}

class SnapshotListItem extends DiffListItem {
  SnapshotListItem(
    Future<HeapSnapshotGraph?> graphReceiver,
    this.displayNumber,
    this._isolateName,
  ) {
    _isProcessing.value = true;
    graphReceiver.whenComplete(() async {
      graph = await graphReceiver;
      _isProcessing.value = false;
    });
  }

  final String _isolateName;

  HeapSnapshotGraph? graph;

  @override
  final int displayNumber;

  String get name => '$_isolateName-$displayNumber';
}

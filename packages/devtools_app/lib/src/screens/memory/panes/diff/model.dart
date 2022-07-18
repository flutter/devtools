// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:vm_service/vm_service.dart';

abstract class DiffListItem with ChangeNotifier {
  String get name;

  /// Number, that, if shown in name, should be unique in the list.
  ///
  /// If the number is not shown, it should be 0.
  int get nameNumber;

  bool isProcessing = false;
}

class InformationListItem extends DiffListItem {
  InformationListItem();

  @override
  String get name => 'Snapshots';

  @override
  int get nameNumber => 0;
}

class SnapshotListItem extends DiffListItem {
  SnapshotListItem(this.graph, this.nameNumber, this.isolateName) {
    isProcessing = true;
    graph.whenComplete(() {
      isProcessing = false;
      notifyListeners();
    });
  }

  final String isolateName;

  @override
  final int nameNumber;
  Future<HeapSnapshotGraph?> graph;

  @override
  String get name => '$isolateName-$nameNumber';
}

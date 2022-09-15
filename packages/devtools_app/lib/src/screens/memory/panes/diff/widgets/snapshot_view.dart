// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../controller/model.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.item}) : super(key: key);

  final SnapshotListItem item;

  @override
  Widget build(BuildContext context) {
    return Text('Content of ${item.name} will be here');
  }
}

// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../shared/heap/model.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({Key? key, required this.heapClass}) : super(key: key);

  final HeapClass? heapClass;

  @override
  Widget build(BuildContext context) {
    final theClass = heapClass;
    if (theClass == null) {
      return const Center(
        child: Text('Select class to see details here.'),
      );
    }
    return Center(child: Text('Details for ${theClass.fullName} will be here'));
  }
}

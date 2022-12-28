import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:vm_service/vm_service.dart';

// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

typedef SampleObtainer = InstanceRef Function();

class InstanceSetView extends StatelessWidget {
  const InstanceSetView({
    super.key,
    required this.count,
    required this.sampleObtainer,
    required this.showMenu,
  }) : assert(showMenu == (sampleObtainer == null));

  final int count;
  final SampleObtainer? sampleObtainer;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

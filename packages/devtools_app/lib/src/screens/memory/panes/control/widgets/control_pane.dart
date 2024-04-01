// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../framework/connected/memory_controller.dart';
import 'primary_controls.dart';
import 'secondary_controls.dart';

class MemoryControlPane extends StatelessWidget {
  const MemoryControlPane({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const PrimaryControls(),
        const Spacer(),
        SecondaryControls(controller: controller),
      ],
    );
  }
}

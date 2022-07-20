// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to class objects in the Dart VM.
class VmCodeDisplay extends StatelessWidget {
  const VmCodeDisplay({
    required this.code,
  });

  final CodeObject code;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [],
    );
  }
}

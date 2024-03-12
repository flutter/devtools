// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

class OfflineMemoryBody extends StatelessWidget {
  const OfflineMemoryBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Memory debugging features are unavailable in disconnected mode.',
    );
  }
}

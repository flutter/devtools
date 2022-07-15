// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Wile this pane is under construction, we do not want our users to see it.
/// Flip this flag locally to test the pane and flip back before checking in.
const shouldShowDiffPane = false;

class DiffPane extends StatefulWidget {
  const DiffPane({Key? key}) : super(key: key);

  @override
  State<DiffPane> createState() => _DiffPaneState();
}

class _DiffPaneState extends State<DiffPane> {
  @override
  Widget build(BuildContext context) {
    return const Text('hello, I am diff pane');
  }
}

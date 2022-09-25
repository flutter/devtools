// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../controller/heap_diff.dart';

class ClassesTableDiff extends StatefulWidget {
  const ClassesTableDiff({super.key, required this.classes});

  final DiffHeapClasses classes;

  @override
  State<ClassesTableDiff> createState() => _ClassesTableDiffState();
}

class _ClassesTableDiffState extends State<ClassesTableDiff> {
  @override
  Widget build(BuildContext context) {
    return const Text('diff classes table will be here');
  }
}

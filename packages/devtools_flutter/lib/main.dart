// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'src/config.dart';

void main() {
  final config = Config();
  runApp(
    MaterialApp(
      theme: ThemeData.light(),
      routes: config.routes,
    ),
  );
}

// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/primitives/listenable.dart';
import '../../../shared/screen.dart';
import 'connected_screen_body.dart';

class MemoryScreen extends Screen {
  MemoryScreen() : super.fromMetaData(ScreenMetaData.memory);

  static final id = ScreenMetaData.memory.id;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  String get docPageId => id;

  @override
  Widget buildScreenBody(BuildContext context) => const MemoryBody();

  // TODO(polina-c): when embedded and VSCode console features are implemented,
  // should be in native console in VSCode
  @override
  bool showConsole(bool embed) => true;
}

class MemoryBody extends StatefulWidget {
  const MemoryBody({super.key});

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody> {
  @override
  void initState() {
    super.initState();
    ga.screen(MemoryScreen.id);
  }

  @override
  Widget build(BuildContext context) {
    // TODO(polina-c): load static body if not connected.
    return const ConnectedMemoryBody();
  }
}

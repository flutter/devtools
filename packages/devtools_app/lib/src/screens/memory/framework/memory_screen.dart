// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/primitives/listenable.dart';
import '../../../shared/screen.dart';
import '../../../shared/utils.dart';
import 'connected/screen_body.dart';
import 'memory_controller.dart';
import 'offline/screen_body.dart';

class MemoryScreen extends Screen {
  MemoryScreen() : super.fromMetaData(ScreenMetaData.memory);

  static final id = ScreenMetaData.memory.id;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    return const MemoryBody();
  }

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

class MemoryBodyState extends State<MemoryBody>
    with
        ProvidedControllerMixin<MemoryController, MemoryBody>,
        AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    ga.screen(MemoryScreen.id);
  }

  ValueListenable<MemoryInitializationStatus>? _initialization;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    _initialization?.removeListener(onUpdateInitialization);
    _initialization = controller.initializationStatus;
    addAutoDisposeListener(_initialization, onUpdateInitialization);
    onUpdateInitialization();
  }

  void onUpdateInitialization() => setState(() {});

  @override
  Widget build(BuildContext context) {
    switch (controller.initializationStatus.value) {
      case MemoryInitializationStatus.offline:
        return const OfflineMemoryBody();
      case MemoryInitializationStatus.connected:
        return const ConnectedMemoryBody();
      case MemoryInitializationStatus.none:
        return const Center(child: Text('Initializing...'));
    }
  }
}

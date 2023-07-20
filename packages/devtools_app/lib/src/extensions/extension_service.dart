// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../shared/globals.dart';
import '../shared/primitives/auto_dispose.dart';
import 'extension_model.dart';

class ExtensionService extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<List<DevToolsExtensionConfig>> get availableExtensions =>
      _availableExtensions;
  final _availableExtensions = ValueNotifier<List<DevToolsExtensionConfig>>([]);

  void initialize() {
    addAutoDisposeListener(serviceManager.connectedState, () {
      _refreshAvailableExtensions();
    });
  }

  // TODO(kenz): actually look up the available extensions from devtools server,
  // based on the root path(s) from the available isolate(s).
  int _count = 0;
  void _refreshAvailableExtensions() {
    _availableExtensions.value =
        debugExtensions.sublist(0, _count++ % (debugExtensions.length + 1));
  }
}

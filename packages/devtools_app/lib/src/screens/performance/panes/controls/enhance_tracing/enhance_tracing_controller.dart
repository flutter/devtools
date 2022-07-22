// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../service/service_extensions.dart' as extensions;

final enhanceTracingExtensions = [
  extensions.profileWidgetBuilds,
  extensions.profileUserWidgetBuilds,
  extensions.profileRenderObjectLayouts,
  extensions.profileRenderObjectPaints,
];

class EnhanceTracingController extends DisposableController
    with AutoDisposeControllerMixin {
  final showMenuStreamController = StreamController<void>();

  void showEnhancedTracingMenu() {
    showMenuStreamController.add(null);
  }

  @override
  void dispose() {
    showMenuStreamController.close();
    super.dispose();
  }
}

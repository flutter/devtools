// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'initialization.dart';
import 'src/extension_points/extensions_base.dart';
import 'src/extension_points/extensions_external.dart';
import 'src/shared/globals.dart';
import 'src/shared/primitives/utils.dart';

/// This is the entrypoint for running DevTools externally.
///
/// WARNING: This is the external entrypoint for running DevTools.
/// Any initialization that needs to occur, for both google3 and externally,
/// should be added to [runDevTools].
void main() {
  BindingBase.debugZoneErrorsAreFatal = true;
  externalRunDevTools();
}

void externalRunDevTools({
  bool integrationTestMode = false,
  bool shouldEnableExperiments = false,
  List<DevToolsJsonFile> sampleData = const [],
}) {
  // Set the extension points global.
  setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());

  runDevTools(
    integrationTestMode: integrationTestMode,
    shouldEnableExperiments: shouldEnableExperiments,
    sampleData: sampleData,
  );
}

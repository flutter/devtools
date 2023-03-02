// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'initialization.dart';
import 'src/app.dart';
import 'src/extension_points/extensions_base.dart';
import 'src/extension_points/extensions_external.dart';
import 'src/shared/globals.dart';
import 'src/shared/primitives/utils.dart';

/// This is the entrypoint for running DevTools externally.
///
/// WARNING: This is the external entrypoint for running DevTools.
/// Any intialization that needs to occur, for both google3 and externally,
/// should be added to [runDevTools].
void main() async {
  await externalRunDevTools();
}

Future<void> externalRunDevTools({
  bool shouldEnableExperiments = false,
  List<DevToolsJsonFile> sampleData = const [],
}) async {
  // Set the extension points global.
  setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());

  await runDevTools(
    shouldEnableExperiments: shouldEnableExperiments,
    sampleData: sampleData,
  );
}

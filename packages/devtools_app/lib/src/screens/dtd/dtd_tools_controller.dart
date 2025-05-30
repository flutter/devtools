// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';

import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';

/// The [DevToolsScreenController] for the `DTDTools` screen.
///
/// This class is responsible for managing the state of the `DTDTools` screen.
class DTDToolsController extends DevToolsScreenController
    with AutoDisposeControllerMixin {
  @override
  final screenId = ScreenMetaData.dtdTools.id;

  /// The [DTDManager] that manages the DTD connection for this screen.
  ///
  /// This instance of [DTDManager] is intentionally separate from the global
  /// [DTDManager] so that we can connect and disconnect from DTD instances
  /// to inspect them without affecting other screens.
  final localDtdManager = DTDManager();

  @override
  Future<void> init() async {
    if (dtdManager.hasConnection) {
      await localDtdManager.connect(dtdManager.uri!);
    }
    addAutoDisposeListener(dtdManager.connection, () async {
      if (dtdManager.hasConnection) {
        await localDtdManager.connect(dtdManager.uri!);
      }
    });
  }

  @override
  Future<void> dispose() async {
    await localDtdManager.disconnect();
    await localDtdManager.dispose();
    super.dispose();
  }
}

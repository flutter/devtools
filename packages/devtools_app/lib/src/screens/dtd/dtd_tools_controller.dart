// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart' as globals;

/// The [DevToolsScreenController] for the `DTDTools` screen.
///
/// This class is responsible for managing the state of the `DTDTools` screen.
class DTDToolsController extends DevToolsScreenController
    with AutoDisposeControllerMixin {
  @override
  final screenId = ScreenMetaData.dtdTools.id;

  bool get useGlobalDtd => _useGlobalDtd && kDebugMode;
  bool _useGlobalDtd = false;

  /// The [DTDManager] that manages the DTD connection for this screen.
  ///
  /// By default, this instance of [DTDManager] is intentionally separate from
  /// the global [DTDManager] so that we can connect and disconnect from DTD
  /// instances to inspect them without affecting other screens.
  ///
  /// However, in debug mode, we can optionally use the global [DTDManager]
  /// (if specifically requested) to set the DTD instance that the entire
  /// DevTools is connected to.
  DTDManager get activeDtdManager =>
      useGlobalDtd ? globals.dtdManager : _localDtdManager;
  DTDManager get localDtdManager => _localDtdManager;

  final _localDtdManager = DTDManager();

  @override
  Future<void> init() async {
    if (globals.dtdManager.hasConnection) {
      await activeDtdManager.connect(globals.dtdManager.uri!);
    }
    addAutoDisposeListener(globals.dtdManager.connection, () async {
      if (globals.dtdManager.hasConnection && !_useGlobalDtd) {
        await activeDtdManager.connect(globals.dtdManager.uri!);
      }
    });
  }

  Future<void> connectDtd(Uri uri, {bool connectToGlobalDtd = false}) async {
    _useGlobalDtd = connectToGlobalDtd;
    await activeDtdManager.connect(uri);
  }

  @override
  Future<void> dispose() async {
    await activeDtdManager.disconnect();
    await activeDtdManager.dispose();
    super.dispose();
  }
}

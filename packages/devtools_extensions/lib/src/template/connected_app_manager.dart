// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/service.dart';
import 'package:vm_service/vm_service.dart';

class ConnectedAppManager {
  bool get hasConnectedApp => _vmServiceUri != null;

  VmService? vmService;
  Uri? _vmServiceUri;

  Future<void> connectToVmService(String? vmServiceUri) async {
    if (vmServiceUri == null) {
      vmService = null;
      _vmServiceUri = null;
      return;
    }

    final finishedCompleter = Completer<void>();
    vmService = await connect<VmService>(
      uri: Uri.parse(vmServiceUri),
      finishedCompleter: finishedCompleter,
      createService: ({
        // ignore: avoid-dynamic, code needs to match API from VmService.
        required Stream<dynamic> /*String|List<int>*/ inStream,
        required void Function(String message) writeMessage,
        required Uri connectedUri,
      }) {
        _vmServiceUri = connectedUri;
        return VmService(inStream, writeMessage);
      },
    );
  }
}

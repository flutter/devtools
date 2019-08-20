// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../globals.dart';

class SettingsController {
  SettingsController({this.onFlagListChange, this.onSdkVersionChange});

  final Function(FlagList) onFlagListChange;
  final Function(String) onSdkVersionChange;

  Future<String> _getSdkVersion() async {
    final isAnyFlutterApp = await serviceManager.connectedApp.isAnyFlutterApp;
    return '${isAnyFlutterApp ? 'Flutter' : 'Dart'} SDK Version: ${serviceManager.sdkVersion}';
  }

  Future<void> entering() async {
    onFlagListChange(await serviceManager.service.getFlagList());
    onSdkVersionChange(await _getSdkVersion());
  }
}

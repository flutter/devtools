// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../globals.dart';

class SettingsController {
  SettingsController({this.onFlagListReady, this.onIsAnyFlutterAppReady});

  final Function(FlagList) onFlagListReady;
  final Function(bool) onIsAnyFlutterAppReady;

  void entering() {
    serviceManager.service.getFlagList().then((flagList) {
      onFlagListReady(flagList);
    });
    serviceManager.connectedApp.isAnyFlutterApp.then((isAnyFlutterApp) {
      onIsAnyFlutterAppReady(isAnyFlutterApp);
    });
  }
}

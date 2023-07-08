// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import 'analytics/constants.dart' as gac;
import 'connected_app.dart';
import 'connection_info.dart';
import 'dialogs.dart';
import 'globals.dart';
import 'ui/vm_flag_widgets.dart';

class DeviceDialog extends StatelessWidget {
  const DeviceDialog({super.key, required this.connectedApp});

  final ConnectedApp connectedApp;

  @override
  Widget build(BuildContext context) {
    final VM? vm = serviceManager.vm;
    if (vm == null || !serviceManager.connectedAppInitialized) {
      return const SizedBox();
    }

    return DevToolsDialog(
      title: const DialogTitleText('Device Info'),
      content: const ConnectedAppSummary(),
      actions: [
        const ConnectToNewAppButton(
          gaScreen: gac.devToolsMain,
          elevated: true,
        ),
        if (connectedApp.isRunningOnDartVM!)
          const ViewVmFlagsButton(
            gaScreen: gac.devToolsMain,
            elevated: true,
          ),
        const DialogCloseButton(),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}

// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../api/vs_code_api.dart';

class DeviceSelector extends StatelessWidget {
  const DeviceSelector({
    super.key,
    required this.api,
    required this.deviceInfo,
  });

  final VsCodeDevicesEvent deviceInfo;
  final VsCodeApi api;

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final device in deviceInfo.devices)
          TableRow(
            children: [
              TextButton(
                child: Text(device.name),
                onPressed: () => unawaited(api.selectDevice(device.id)),
              ),
              Text(
                device.id == deviceInfo.selectedDeviceId ? '(selected)' : '',
              ),
            ],
          ),
      ],
    );
  }
}

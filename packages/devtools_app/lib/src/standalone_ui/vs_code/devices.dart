// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../api/vs_code_api.dart';

class Devices extends StatelessWidget {
  const Devices(
    this.api,
    this.devices, {
    required this.selectedDeviceId,
    super.key,
  });

  final VsCodeApi api;
  final List<VsCodeDevice> devices;
  final String? selectedDeviceId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Devices',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (devices.isEmpty)
          const Text('Connect a device or enable web/desktop platforms.')
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final device in devices)
                _createDeviceRow(
                  context,
                  device,
                  isSelected: device.id == selectedDeviceId,
                ),
            ],
          ),
      ],
    );
  }

  TableRow _createDeviceRow(
    BuildContext context,
    VsCodeDevice device, {
    required bool isSelected,
  }) {
    return TableRow(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            child: Text(device.name),
            onPressed: () => unawaited(api.selectDevice(device.id)),
          ),
        ),
        // TODO(dantup): Use a highlighted/select row for this instead of text.
        Text(isSelected ? 'current device' : ''),
      ],
    );
  }
}

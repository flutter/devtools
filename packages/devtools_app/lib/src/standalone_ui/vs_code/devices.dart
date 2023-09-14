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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Devices',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (devices.isEmpty)
          const Text('Connect a device or enable web/desktop platforms.')
        else
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final device in devices)
                _createDeviceRow(
                  colorScheme,
                  device,
                  isSelected: device.id == selectedDeviceId,
                ),
            ],
          ),
      ],
    );
  }

  TableRow _createDeviceRow(
    ColorScheme colorScheme,
    VsCodeDevice device, {
    required bool isSelected,
  }) {
    return TableRow(
      decoration: BoxDecoration(color: isSelected ? colorScheme.primary : null),
      children: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              shape: const ContinuousRectangleBorder(),
            ),
            child: Text(
              device.name,
              style:
                  TextStyle(color: isSelected ? colorScheme.onPrimary : null),
            ),
            onPressed: () => unawaited(api.selectDevice(device.id)),
          ),
        ),
      ],
    );
  }
}

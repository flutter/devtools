// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../screens/inspector/layout_explorer/ui/theme.dart';
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Devices',
          style: theme.textTheme.titleMedium,
        ),
        if (devices.isEmpty)
          const Text('Connect a device or enable web/desktop platforms.')
        else
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final device in devices)
                _createDeviceRow(
                  theme,
                  device,
                  isSelected: device.id == selectedDeviceId,
                ),
            ],
          ),
      ],
    );
  }

  TableRow _createDeviceRow(
    ThemeData theme,
    VsCodeDevice device, {
    required bool isSelected,
  }) {
    final backgroundColor = isSelected ? theme.colorScheme.secondary : null;
    final foregroundColor = isSelected
        ? theme.colorScheme.onSecondary
        : theme.colorScheme.secondary;

    return TableRow(
      decoration: BoxDecoration(color: backgroundColor),
      children: [
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              shape: const ContinuousRectangleBorder(),
              textStyle: theme.regularTextStyle,
            ),
            icon: Icon(
              device.iconData,
              size: actionsIconSize,
              color: foregroundColor,
            ),
            label: Text(
              device.name,
              style: theme.regularTextStyle.copyWith(color: foregroundColor),
            ),
            onPressed: () => unawaited(api.selectDevice(device.id)),
          ),
        ),
      ],
    );
  }
}

extension on VsCodeDevice {
  IconData get iconData {
    return switch ((category, platformType)) {
      ('desktop', 'macos') => Icons.desktop_mac_outlined,
      ('desktop', 'windows') => Icons.desktop_windows_outlined,
      ('desktop', _) => Icons.computer_outlined,
      ('mobile', 'android') => Icons.phone_android_outlined,
      ('mobile', 'ios') => Icons.phone_iphone_outlined,
      ('mobile', _) => Icons.smartphone_outlined,
      ('web', _) => Icons.web_outlined,
      _ => Icons.device_unknown_outlined,
    };
  }
}

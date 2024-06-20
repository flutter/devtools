// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../service/editor/api_classes.dart';
import '../../service/editor/editor_client.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;

class Devices extends StatelessWidget {
  Devices({
    required this.editor,
    required Map<String, EditorDevice> devices,
    required this.selectedDeviceId,
    super.key,
  })  : supportedDevices = {
          for (final MapEntry(key: id, value: device) in devices.entries)
            if (device.supported) id: device,
        },
        unsupportedDevicePlatformTypes = devices.values
            .where((device) => !device.supported)
            .map((device) => device.platformType)
            .nonNulls
            .toSet();

  final EditorClient editor;
  final Map<String, EditorDevice> supportedDevices;
  final Set<String> unsupportedDevicePlatformTypes;
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
        if (supportedDevices.isEmpty)
          const Text('Connect a device or enable web/desktop platforms.')
        else
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final device in supportedDevices.values)
                _createDeviceRow(
                  theme,
                  device,
                  isSelected: device.id == selectedDeviceId,
                ),
              for (final platformType in unsupportedDevicePlatformTypes)
                _createPlatformTypeEnablerRow(
                  theme,
                  platformType,
                ),
            ],
          ),
      ],
    );
  }

  TableRow _createDeviceRow(
    ThemeData theme,
    EditorDevice device, {
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
            onPressed: () {
              ga.select(
                gac.VsCodeFlutterSidebar.id,
                gac.VsCodeFlutterSidebar.changeSelectedDevice.name,
              );
              unawaited(editor.selectDevice(device));
            },
          ),
        ),
      ],
    );
  }

  TableRow _createPlatformTypeEnablerRow(ThemeData theme, String platformType) {
    final foregroundColor = theme.colorScheme.secondary;

    return TableRow(
      children: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              shape: const ContinuousRectangleBorder(),
              textStyle: theme.regularTextStyle,
            ),
            child: Text(
              'Enable $platformType for this project',
              style: theme.regularTextStyle.copyWith(color: foregroundColor),
            ),
            onPressed: () {
              ga.select(
                gac.VsCodeFlutterSidebar.id,
                gac.VsCodeFlutterSidebar.enablePlatformType(platformType),
              );
              unawaited(editor.enablePlatformType(platformType));
            },
          ),
        ),
      ],
    );
  }
}

extension on EditorDevice {
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

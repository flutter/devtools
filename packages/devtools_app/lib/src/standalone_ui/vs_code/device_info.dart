// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import 'temp_api.dart';

/// Widget showing the current selected device for Flutter apps, and a button
/// to change.
class DeviceInfo extends StatefulWidget {
  const DeviceInfo(this.api, {super.key});

  final VsCodeApi api;

  @override
  State<DeviceInfo> createState() => _DeviceInfoState();
}

class _DeviceInfoState extends State<DeviceInfo> {
  Object? _currentDevice;
  late Stream<Object?> _deviceChangedStream;

  @override
  void initState() {
    super.initState();

    _deviceChangedStream = widget.api.selectedDeviceChanged
        .map((newDevice) => _currentDevice = newDevice['device']);

    unawaited(
      widget.api.getSelectedDevice().then((newDevice) {
        setState(() {
          _currentDevice = newDevice;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _deviceChangedStream,
      initialData: _currentDevice,
      builder: (context, snapshot) {
        return Column(
          children: [
            Text('Current device is $_currentDevice'),
            TextButton(
              onPressed: widget.api.showDeviceSelector,
              child: const Text('Change Device'),
            )
          ],
        );
      },
    );
  }
}

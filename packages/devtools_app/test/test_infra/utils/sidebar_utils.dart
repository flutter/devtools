// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_app/src/service/editor/api_classes.dart';

EditorDebugSession generateDebugSession({
  required String debuggerType,
  required String deviceId,
  String? flutterMode,
  String? projectRootPath,
}) {
  return EditorDebugSession(
    id: '$debuggerType-$deviceId-$flutterMode',
    name: 'Session ($debuggerType) ($deviceId)',
    vmServiceUri: 'ws://127.0.0.1:1234/ws',
    flutterMode: flutterMode,
    flutterDeviceId: deviceId,
    debuggerType: debuggerType,
    projectRootPath: projectRootPath ??
        (Platform.isWindows ? r'C:\mock\root\path' : '/mock/root/path'),
  );
}

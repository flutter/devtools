// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:devtools_app/src/shared/editor/api_classes.dart';

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
    projectRootPath:
        projectRootPath ??
        (Platform.isWindows ? r'C:\mock\root\path' : '/mock/root/path'),
  );
}

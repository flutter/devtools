// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';

Future<void> loadOfflineSnapshot(String path) async {
  final completer = Completer<bool>();
  final importController = ImportController((screenId) {
    completer.complete(true);
  });

  final data = await File(path).readAsString();
  final jsonFile = DevToolsJsonFile(
    name: path,
    data: jsonDecode(data),
    lastModifiedTime: DateTime.now(),
  );
  importController.importData(jsonFile);
  await completer.future;
}

// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../file/file.dart';
import 'import_export.dart';

ExportControllerDesktop createExportController() {
  throw UnimplementedError();
}

class ExportControllerDesktop extends ExportController {
  ExportControllerDesktop() : super.impl();

  static final _fs = FileIO();

  @override
  void saveFile({
    required String content,
    required String fileName,
  }) {
    _fs.writeStringToFile(fileName, content);
  }

  @override
  void saveDataFile({required Uint8List content, required String fileName}) {
    // TODO: implement saveDataFile
  }
}

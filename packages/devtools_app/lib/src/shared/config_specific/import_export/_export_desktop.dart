// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '_file_desktop.dart';
import 'import_export.dart';

ExportControllerDesktop createExportController() {
  return ExportControllerDesktop();
}

class ExportControllerDesktop extends ExportController {
  ExportControllerDesktop() : super.impl();

  static final _fs = FileSystemDesktop();

  @override
  void saveFile<T>({
    required T content,
    required String fileName,
  }) {
    _fs.writeContentsToFile<T>(fileName, content);
  }
}

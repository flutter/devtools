// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:path/path.dart' as path;

import '../file/file.dart';
import 'import_export.dart';

ExportControllerDesktop createExportController() {
  return ExportControllerDesktop();
}

class ExportControllerDesktop extends ExportController {
  ExportControllerDesktop() : super.impl();

  static final _fs = FileIO();

  @override
  void saveFile<T>({
    required T content,
    required String fileName,
  }) {
    if (content is String) {
      _fs.writeStringToFile(fileName, content);
    } else if (content is Uint8List) {
      _fs.writeStringToFile(toAbsolutePath(fileName), content);
    } else {
      throw StateError('Unsupported content type: $T');
    }
  }

  String toAbsolutePath(String fileName) {
    if (!path.isRelative(fileName)) return fileName;
    return path.join(_fs.exportDirectoryName(), fileName);
  }
}

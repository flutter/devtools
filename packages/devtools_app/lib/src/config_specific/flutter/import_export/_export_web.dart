// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'import_export.dart';

ExportControllerWeb createExportController() {
  return ExportControllerWeb();
}

class ExportControllerWeb extends ExportController {
  ExportControllerWeb() : super.impl();

  @override
  void downloadFile(String filename, String contents) {
    final element = document.createElement('a');
    element.setAttribute('href', Url.createObjectUrl(Blob([contents])));
    element.setAttribute('download', filename);
    element.style.display = 'none';
    document.body.append(element);
    element.click();
    element.remove();
  }
}

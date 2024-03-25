// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' hide NodeGlue;

import 'import_export.dart';

ExportControllerWeb createExportController() {
  return ExportControllerWeb();
}

class ExportControllerWeb extends ExportController {
  ExportControllerWeb() : super.impl();

  void _downloadJsObject({
    // ignore: avoid-dynamic, there is not better way in this case
    required dynamic content,
    required String fileName,
  }) {
    final element = document.createElement('a') as HTMLAnchorElement;
    element.setAttribute(
      'href',
      // ignore: avoid-dynamic, avoid_dynamic_calls, there is not better way in this case,
      URL.createObjectURL(Blob(([content.toJS] as dynamic).toJS) as JSObject),
    );
    element.setAttribute('download', fileName);
    element.style.display = 'none';
    (document.body as HTMLBodyElement).append(element as JSAny);
    element.click();
    element.remove();
  }

  @override
  void saveFile({
    required String content,
    required String fileName,
  }) {
    _downloadJsObject(content: content, fileName: fileName);
  }

  @override
  void saveDataFile({
    required Uint8List content,
    required String fileName,
  }) {
    _downloadJsObject(content: content, fileName: fileName);
  }
}

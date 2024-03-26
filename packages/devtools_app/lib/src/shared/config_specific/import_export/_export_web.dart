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

  @override
  void saveFile<T>({
    required T content,
    required String fileName,
  }) {
    final element = document.createElement('a') as HTMLAnchorElement;

    late final Blob blob;

    if (content is String) {
      blob = Blob([content.toJS].toJS);
    } else if (content is Uint8List) {
      blob = Blob([content.toJS].toJS);
    } else {
      throw 'Unsupported content type: $T';
    }

    element.setAttribute('href', URL.createObjectURL(blob as JSObject));
    element.setAttribute('download', fileName);
    element.style.display = 'none';
    (document.body as HTMLBodyElement).append(element as JSAny);
    element.click();
    element.remove();
  }
}

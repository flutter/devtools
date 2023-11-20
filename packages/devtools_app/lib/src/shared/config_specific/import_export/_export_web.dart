// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(kenz): remove this once the package:web version has been upgraded.
// ignore_for_file: avoid-unused-ignores

import 'dart:js_interop';

import 'package:web/helpers.dart' hide NodeGlue;

import 'import_export.dart';

ExportControllerWeb createExportController() {
  return ExportControllerWeb();
}

class ExportControllerWeb extends ExportController {
  ExportControllerWeb() : super.impl();

  @override
  void saveFile({
    required String content,
    required String fileName,
  }) {
    final element = document.createElement('a') as HTMLAnchorElement;
    element.setAttribute(
      'href',
      // TODO(srujzs): This is necessary in order to support package:web 0.4.0.
      // This was not needed with 0.3.0, hence the lint.
      // ignore: avoid-unnecessary-type-casts
      URL.createObjectURL(Blob([content.toJS].toJS) as JSObject),
    );
    element.setAttribute('download', fileName);
    element.style.display = 'none';
    // TODO(srujzs): This is necessary in order to support package:web 0.4.0.
    // This was not needed with 0.3.0, hence the lint.
    // ignore: avoid-unnecessary-type-casts
    (document.body as HTMLBodyElement).append(element as JSAny);
    element.click();
    element.remove();
  }
}

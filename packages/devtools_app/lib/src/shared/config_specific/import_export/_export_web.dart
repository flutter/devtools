// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:web/web.dart' hide NodeGlue;

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
      URL.createObjectURL(Blob([content.toJS].toJS) as JSObject),
    );
    element.setAttribute('download', fileName);
    element.style.display = 'none';
    (document.body as HTMLBodyElement).append(element as JSAny);
    element.click();
    element.remove();
  }

  @override
  void saveDataFile({
    required Uint8List content,
    required String fileName,
  }) {
    final file = XFile(fileName, bytes: content);
    file.saveTo(fileName);
  }

  // @override
  // void saveDataFile({
  //   required Uint8List content,
  //   required String fileName,
  // }) {
  //   final element = document.createElement('a') as HTMLAnchorElement;

  //   print(1);
  //   final c1 = content.toJS;

  //   print(2);
  //   final c2 = [c1].toJS;
  //   print(3);
  //   final c3 = Blob(c2);
  //   print(4);
  //   element.setAttribute(
  //     'href',
  //     URL.createObjectURL(c3 as JSObject),
  //   );
  //   print(5);
  //   element.setAttribute('download', fileName);
  //   element.style.display = 'none';
  //   (document.body as HTMLBodyElement).append(element as JSAny);
  //   element.click();
  //   element.remove();

  //   print(c1);
  // }
}

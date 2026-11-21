// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'import_export.dart';

ExportControllerWeb createExportController() {
  return ExportControllerWeb();
}

const _revokeObjectUrlDelay = Duration(seconds: 1);

class ExportControllerWeb extends ExportController {
  ExportControllerWeb() : super.impl();

  @override
  void saveFile<T>({required T content, required String fileName}) {
    final element = document.createElement('a') as HTMLAnchorElement;

    final Blob blob;
    if (content is String) {
      blob = Blob([content.toJS].toJS);
    } else if (content is Uint8List) {
      blob = Blob([content.toJS].toJS);
    } else {
      throw 'Unsupported content type: $T';
    }

    final objectUrl = URL.createObjectURL(blob);
    element.setAttribute('href', objectUrl);
    element.setAttribute('download', fileName);
    element.style.display = 'none';
    (document.body as HTMLBodyElement).append(element);
    element.click();
    element.remove();

    // Release the memory held by the blob. Revoking synchronously can cancel
    // the download in some browsers, so wait for the download to start.
    Timer(_revokeObjectUrlDelay, () => URL.revokeObjectURL(objectUrl));
  }
}

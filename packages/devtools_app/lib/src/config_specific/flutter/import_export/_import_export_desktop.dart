// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../flutter/controllers.dart';
import '../../../flutter/notifications.dart';
import '../../file/file.dart';
import '_import_export_base.dart';

class ImportController extends ImportControllerBase<PointerEvent> {
  ImportController(
    NotificationsState notifications,
    ProvidedControllers controllers,
  ) : super(notifications, controllers);

  // TODO(kenz): we should support a file picker import for desktop and handle
  // that here.

  @override
  void handleDragAndDrop(PointerEvent event) {
    // TODO(kenz): implement once Desktop support is available. See
    // https://github.com/flutter/flutter/issues/30719.
  }
}

class ExportController extends ExportControllerBase {
  static final _fs = FileSystem();

  @override
  void downloadFile(String filename, String contents) {
    _fs.writeStringToFile(filename, contents);
  }
}

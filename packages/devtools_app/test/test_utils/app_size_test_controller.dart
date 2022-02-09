// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:flutter/widgets.dart';

class AppSizeTestController extends AppSizeController {
  @override
  void loadTreeFromJsonFile({
    @required DevToolsJsonFile jsonFile,
    @required void Function(String error) onError,
    bool delayed = false,
  }) async {
    if (delayed) {
      await delay();
    }
    super.loadTreeFromJsonFile(jsonFile: jsonFile, onError: onError);
  }

  @override
  void loadDiffTreeFromJsonFiles({
    @required DevToolsJsonFile oldFile,
    @required DevToolsJsonFile newFile,
    @required void Function(String error) onError,
    bool delayed = false,
  }) async {
    if (delayed) {
      await delay();
    }
    super.loadDiffTreeFromJsonFiles(
        oldFile: oldFile, newFile: newFile, onError: onError);
  }
}

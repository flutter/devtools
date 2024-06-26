// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

File? checkFileExists(String path) {
  final testFile = File.fromUri(Uri.parse(path));
  if (!testFile.existsSync()) {
    stdout.writeln('Could not locate file at $path.');
    return null;
  }
  return testFile;
}

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Attempts to detect the package root of [fileUriString].
///
/// This method uses the heuristics that a Dart executable within a Dart package
/// should reside in one of the following top-level folders: 'lib', 'bin',
/// 'integration_test', 'test', or 'benchmark'.
String packageRootFromFileUriString(String fileUriString) {
  // TODO(kenz): for robustness, consider sending the root library uri to the
  // server and having the server look for the package folder that contains the
  // `.dart_tool` directory.
  final directoryRegExp =
      RegExp(r'\/(lib|bin|integration_test|test|benchmark|example)\/.+\.dart');
  final directoryIndex = fileUriString.indexOf(directoryRegExp);
  if (directoryIndex != -1) {
    fileUriString = fileUriString.substring(0, directoryIndex);
  }
  return fileUriString;
}

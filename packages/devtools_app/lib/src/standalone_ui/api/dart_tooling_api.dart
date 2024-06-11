// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'vs_code_api.dart';

/// An API exposed to Dart tooling surfaces.
///
/// APIs are grouped into child APIs that are exposed as fields. Each field is a
/// `Future` that will return null if the requested API is unavailable (for
/// example the VS Code APIs if not running inside VS Code, or the LSP APIs if
/// no LSP server is available).
abstract interface class DartToolingApi {
  /// Access to APIs provided by VS Code and/or the Dart/Flutter VS Code
  /// extensions.
  Future<VsCodeApi?> get vsCode;

  void dispose();
}

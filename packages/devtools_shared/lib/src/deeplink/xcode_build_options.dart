// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

/// The Xcode build options of a iOS build of a Flutter project.
extension type const XcodeBuildOptions._(Map<String, Object?> _json) {
  factory XcodeBuildOptions.fromJson(String json) =>
      XcodeBuildOptions._(jsonDecode(json));

  /// Used when the the server can't retrieve ios build options.
  static const empty =
      XcodeBuildOptions._({_kConfigurationsKey: [], _kTargetsKey: []});

  static const _kConfigurationsKey = 'configurations';
  static const _kTargetsKey = 'targets';

  /// The available configurations for iOS build of this Flutter project.
  List<String> get configurations =>
      (_json[_kConfigurationsKey] as List).cast<String>();

  /// The available targets for iOS build of this Flutter project.
  List<String> get targets => (_json[_kTargetsKey] as List).cast<String>();
}

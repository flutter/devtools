// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

/// The Xcode build options of a iOS build of a Flutter project.
class XcodeBuildOptions {
  const XcodeBuildOptions._(this.configurations, this.targets);

  factory XcodeBuildOptions.fromJson(String json) {
    final jsonObject = jsonDecode(json);
    return XcodeBuildOptions._(
      jsonObject[_kConfigurationsKey].cast<String>() as List<String>,
      jsonObject[_kTargetsKey].cast<String>() as List<String>,
    );
  }

  /// Used when the the server can't retrieve ios build options.
  static const empty = XcodeBuildOptions._(<String>[], <String>[]);

  static const _kConfigurationsKey = 'configurations';
  static const _kTargetsKey = 'targets';

  /// The available configurations for iOS build of this Flutter project.
  final List<String> configurations;

  /// The available targets for iOS build of this Flutter project.
  final List<String> targets;
}

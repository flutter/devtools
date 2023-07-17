// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

// TODO(kenz): share this with devtools_server so that we do not duplicate.

/// Describes an extension that can be dynamically loaded into a custom screen
/// in DevTools.
class DevToolsExtensionConfig {
  DevToolsExtensionConfig._({
    required this.name,
    required this.path,
    required this.issueTrackerLink,
    required this.version,
    required this.materialIconCodePoint,
  });

  factory DevToolsExtensionConfig.parse(Map<String, Object?> json) {
    // Defaults to the code point for [Icons.extensions_outlined] if null.
    final codePoint = json[materialIconCodePointKey] as int? ?? 0xf03f;
    return DevToolsExtensionConfig._(
      name: json[nameKey]! as String,
      path: json[pathKey]! as String,
      issueTrackerLink: json[issueTrackerKey]! as String,
      version: json[versionKey]! as String,
      materialIconCodePoint: codePoint,
    );
  }

  static const nameKey = 'name';
  static const pathKey = 'path';
  static const issueTrackerKey = 'issueTracker';
  static const versionKey = 'version';
  static const materialIconCodePointKey = 'materialIconCodePoint';

  final String name;
  final String path;
  final String issueTrackerLink;
  final String version;
  final int materialIconCodePoint;

  Map<String, Object?> toJson() => {
        nameKey: name,
        pathKey: path,
        issueTrackerKey: issueTrackerLink,
        versionKey: version,
        materialIconCodePointKey: materialIconCodePoint,
      };
}

extension ExtensionConfigExtension on DevToolsExtensionConfig {
  IconData get icon => IconData(
        materialIconCodePoint,
        fontFamily: 'MaterialIcons',
      );
}

// TODO(kenz): remove these once the DevTools extensions feature has shipped.
final List<DevToolsExtensionConfig> debugPlugins = [
  DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'foo',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '1.0.0',
    DevToolsExtensionConfig.pathKey: '/path/to/foo',
  }),
  DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'bar',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '2.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
    DevToolsExtensionConfig.pathKey: '/path/to/bar',
  }),
  DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'provider',
    DevToolsExtensionConfig.issueTrackerKey:
        'https://github.com/rrousselGit/provider/issues',
    DevToolsExtensionConfig.versionKey: '3.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe50a,
    DevToolsExtensionConfig.pathKey: '/path/to/provider',
  }),
];

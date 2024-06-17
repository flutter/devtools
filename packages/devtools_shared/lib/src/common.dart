// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:path/path.dart' as path;

/// Describes an instance of the Dart Tooling Daemon.
typedef DTDConnectionInfo = ({String? uri, String? secret});

/// The name of the Directory where a Dart application's package config file is
/// stored.
const dartToolDirectoryName = '.dart_tool';

/// The name of the package config file for a Dart application.
const packageConfigFileName = 'package_config.json';

/// The path identifier for the package config URI for a Dart application.
///
/// The package config file lives at '.dart_tool/package_config.json'.
final packageConfigIdentifier =
    path.join(dartToolDirectoryName, packageConfigFileName);

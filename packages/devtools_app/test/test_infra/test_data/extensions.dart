// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/src/extensions/extension_model.dart';

final testExtensions = [fooExtension, barExtension, providerExtension];

final fooExtension = DevToolsExtensionConfig.parse({
  DevToolsExtensionConfig.nameKey: 'foo',
  DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
  DevToolsExtensionConfig.versionKey: '1.0.0',
  DevToolsExtensionConfig.pathKey: '/path/to/foo',
  DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
});

final barExtension = DevToolsExtensionConfig.parse({
  DevToolsExtensionConfig.nameKey: 'bar',
  DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
  DevToolsExtensionConfig.versionKey: '2.0.0',
  DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
  DevToolsExtensionConfig.pathKey: '/path/to/bar',
  DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
});

final providerExtension = DevToolsExtensionConfig.parse({
  DevToolsExtensionConfig.nameKey: 'provider',
  DevToolsExtensionConfig.issueTrackerKey:
      'https://github.com/rrousselGit/provider/issues',
  DevToolsExtensionConfig.versionKey: '3.0.0',
  DevToolsExtensionConfig.materialIconCodePointKey: 0xe50a,
  DevToolsExtensionConfig.pathKey: '/path/to/provider',
  DevToolsExtensionConfig.isPubliclyHostedKey: 'true',
});

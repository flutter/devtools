// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/primitives/listenable.dart';
import '../../shared/screen.dart';
import '../extension_model.dart';

class ExtensionScreen extends Screen {
  ExtensionScreen(this.extensionConfig)
      : super.conditional(
          // TODO(kenz): we may need to ensure this is a unique id.
          id: extensionConfig.name,
          title: extensionConfig.name,
          icon: extensionConfig.icon,
          // TODO(kenz): support static DevTools extensions.
          requiresConnection: true,
        );

  final DevToolsExtensionConfig extensionConfig;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  Widget build(BuildContext context) =>
      Text('TODO: iFrame for ${extensionConfig.name}');
}

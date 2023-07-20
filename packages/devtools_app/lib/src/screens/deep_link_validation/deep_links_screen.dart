// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/screen.dart';

class DeepLinksScreen extends Screen {
  DeepLinksScreen()
      : super.conditional(
          id: id,
          requiresConnection: false,
          requiresDartVm: true,
          title: ScreenMetaData.deepLinks.title,
          icon: ScreenMetaData.deepLinks.icon,
        );

  static final id = ScreenMetaData.deepLinks.id;

  // TODO(https://github.com/flutter/devtools/issues/6013): write documentation.
  // @override
  // String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('TODO: build deep link validation tool'),
    );
  }
}

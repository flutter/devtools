// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/ui/icons.dart';
import '../../shared/utils.dart';




class DeepLinkScreen extends Screen {
  DeepLinkScreen()
      : super.conditional(
          id: id,
          worksOffline: true,
          title: ScreenMetaData.deepLink.title,
          icon: Octicons.link,
        );

  static final id = ScreenMetaData.deepLink.id;

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) =>  Container();
}



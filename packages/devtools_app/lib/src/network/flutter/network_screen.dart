// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';

class NetworkScreen extends Screen {
  const NetworkScreen() : super();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('TODO Network Screen'),
    );
  }

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Network',
      icon: Icon(Octicons.rss),
    );
  }
}

// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/screen.dart';

class InfoScreen extends Screen {
  const InfoScreen() : super('Info');

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return const SizedBox();
  }

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      icon: Icon(Icons.info),
      text: 'Info',
    );
  }

}
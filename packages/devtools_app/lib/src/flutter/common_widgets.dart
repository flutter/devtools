// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

// A divider that adds spacing underneath for forms.
class SpacedDivider extends StatelessWidget {
  const SpacedDivider({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10.0),
      child: Divider(thickness: 1.0),
    );
  }
}

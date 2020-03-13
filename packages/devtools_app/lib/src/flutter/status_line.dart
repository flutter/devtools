// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../devtools.dart' as devtools;

/// The status line widget displayed at the bottom of DevTools.
class StatusLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO(devoncarew): Break this into an isolates area, a connection status
    // area, a page specific area, and a documentation link area.

    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 24.0,
      alignment: Alignment.centerLeft,
      child: Text(
        'DevTools ${devtools.version}',
        style: textTheme.bodyText2,
      ),
    );
  }
}

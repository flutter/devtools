// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart' as devtools_shared_ui;
import 'package:flutter/material.dart';

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return devtools_shared_ui.RoundedOutlinedBorder(
      child: Column(
        children: [
          const devtools_shared_ui.AreaPaneHeader(
            roundedTopBorder: false,
            includeTopBorder: false,
            title: Text('This is a section header'),
          ),
          Expanded(
            child: Text(
              'Foo',
              style: Theme.of(context).subtleTextStyle, // Shared style
            ),
          ),
        ],
      ),
    );
  }
}

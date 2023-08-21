// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared component
    return RoundedOutlinedBorder(
      child: Column(
        children: [
          // Shared component
          const AreaPaneHeader(
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

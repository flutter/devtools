// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

class AccessibilityResults extends StatelessWidget {
  const AccessibilityResults({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AreaPaneHeader(title: Text('Audit Results')),
        Expanded(
          child: ListView.builder(
            itemCount: 0,
            itemBuilder: (context, index) {
              return const ListTile(title: Text('Violation Placeholder'));
            },
          ),
        ),
      ],
    );
  }
}

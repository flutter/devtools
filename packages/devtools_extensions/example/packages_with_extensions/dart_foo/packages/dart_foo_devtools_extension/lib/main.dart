// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DartFooDevToolsExtension());
}

class DartFooDevToolsExtension extends StatelessWidget {
  const DartFooDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: Center(
        child: Text(
          '''
This is a basic example to show an extension provided by a pure Dart
package ("package:dart_foo"). For a more interesting example of things
you can do with a DevTools extension, see the example for "package:foo"
instead.
''',
        ),
      ),
    );
  }
}

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
This is a basic example to show a standalone extension. A standalone extension
is an extension that is not a companion tool for an existing package, but rather
is a development tool that can be used on an arbitrary Dart / Flutter project.

This example also shows an example of an extension that does not require a
running application. The app_that_uses_foo project will import this example as a
dev_dependency.

For a more interesting example of things you can do with a DevTools extension,
see the example extension for "package:foo" instead.
''',
        ),
      ),
    );
  }
}

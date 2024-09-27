// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'common/ui.dart';
import 'feature_examples/devtools_event_example.dart';
import 'feature_examples/devtools_extension_api_example.dart';
import 'feature_examples/dtd_example.dart';
import 'feature_examples/expression_evaluation_example.dart';
import 'feature_examples/service_extension_example.dart';

class FooDevToolsExtension extends StatelessWidget {
  const FooDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: FooExtensionHomePage(),
    );
  }
}

class FooExtensionHomePage extends StatelessWidget {
  const FooExtensionHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Foo DevTools Extension'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: denseSpacing),
        child: ListView(
          children: const [
            _ExampleTile(
              number: 1,
              title:
                  'Example of calling service extensions to fetch data from your package',
              requirements: 'Requires a VM service connection.',
              content: ServiceExtensionExample(),
            ),
            _ExampleTile(
              number: 2,
              title:
                  'Example of evaluating expressions to fetch data from your package',
              requirements: 'Requires a VM service connection.',
              content: EvalExample(),
            ),
            _ExampleTile(
              number: 3,
              title: 'Example of calling Dart Tooling Daemon APIs',
              requirements: 'Requires a Dart Tooling Daemon connection.',
              content: DartToolingDaemonExample(),
            ),
            _ExampleTile(
              number: 4,
              title: 'Example of listening for a DevTools event',
              content: ListeningForDevToolsEventExample(),
            ),
            _ExampleTile(
              number: 5,
              title: 'Example of calling DevTools extension APIs',
              content: CallingDevToolsExtensionsAPIsExample(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile({
    required this.number,
    required this.title,
    required this.content,
    this.requirements,
  });

  final int number;
  final String title;
  final String? requirements;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: SectionHeader(
        number: number,
        title: title,
        requirements: requirements,
      ),
      childrenPadding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.only(
            left: 18.0,
            right: 18.0,
            top: densePadding,
            bottom: defaultSpacing,
          ),
          alignment: Alignment.topLeft,
          child: content,
        ),
      ],
    );
  }
}

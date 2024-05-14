// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../common/ui.dart';

/// A widget that shows an example of how to call a service extension over the
/// VM Service protocol.
///
/// This service extension was registered in the parent package (package:foo)
/// using [registerExtension] from dart:developer
/// (https://api.flutter.dev/flutter/dart-developer/registerExtension.html) and
/// then we use the [serviceManager] to call the extension from this DevTools
/// extension.
///
/// Service extensions can only be called when the app is unpaused. In contrast,
/// expression evaluations can be called both when the app is paused and
/// unpaused (see expression_evaluation.dart).
class ServiceExtensionExample extends StatefulWidget {
  const ServiceExtensionExample({super.key});

  @override
  State<ServiceExtensionExample> createState() =>
      _ServiceExtensionExampleState();
}

class _ServiceExtensionExampleState extends State<ServiceExtensionExample> {
  int selectedId = 1;

  void _changeId({required bool increment}) {
    setState(() {
      if (increment) {
        selectedId++;
      } else {
        selectedId--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectedThing(
          selectedThingId: selectedId,
          onIncrement: () => _changeId(increment: true),
          onDecrement: () => _changeId(increment: false),
        ),
        const SizedBox(height: denseSpacing),
        const Flexible(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: denseSpacing),
            child: TableOfThings(),
          ),
        ),
      ],
    );
  }
}

class TableOfThings extends StatefulWidget {
  const TableOfThings({super.key});

  @override
  State<TableOfThings> createState() => _TableOfThingsState();
}

class _TableOfThingsState extends State<TableOfThings> {
  final things = ValueNotifier<List<String>>([]);

  /// Here we call the service extension 'ext.foo.getAllThings' on the main
  /// isolate.
  ///
  /// This service extension was registered in `FooController.initFoo` in
  /// package:foo (see devtools_extensions/example/packages_with_extensions/foo/packages/foo/lib/src/foo_controller.dart).
  ///
  /// It is important to note that we are calling the service extension on the
  /// main isolate here using the [serviceManager.callServiceExtensionOnMainIsolate].
  ///
  /// To call a service extension that was registered in a different isolate,
  /// you can use [serviceManager.service.callServiceExtension], but this call
  /// MUST include the isolate id of the isolate that the service extension was
  /// registered in.
  Future<void> _refreshThings() async {
    try {
      final response = await serviceManager
          .callServiceExtensionOnMainIsolate('ext.foo.getAllThings');
      final responseThings = response.json?['things'] as List<String>?;
      things.value = responseThings ?? <String>[];
    } catch (e) {
      print('Error fetching all things: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refreshThings());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: _refreshThings,
          child: const Text('Refresh things'),
        ),
        const SizedBox(height: denseSpacing),
        ValueListenableBuilder(
          valueListenable: things,
          builder: (context, things, _) {
            return Table(
              border: TableBorder.all(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              columnWidths: const <int, TableColumnWidth>{
                0: FlexColumnWidth(),
                1: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: <TableRow>[
                TableRow(
                  children: <Widget>[
                    _GridEntry(
                      text: 'Id',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    _GridEntry(
                      text: 'Thing',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                for (int i = 0; i < things.length; i++)
                  TableRow(
                    children: [
                      _GridEntry(text: '$i'),
                      _GridEntry(text: things[i]),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GridEntry extends StatelessWidget {
  const _GridEntry({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: style ?? Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class SelectedThing extends StatefulWidget {
  const SelectedThing({
    required this.selectedThingId,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int selectedThingId;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  State<SelectedThing> createState() => _SelectedThingState();
}

class _SelectedThingState extends State<SelectedThing> {
  String selectedThing = 'unknown';

  /// Here we call the service extension 'ext.foo.getThing' on the main isolate.
  ///
  /// This service extension was registered in `FooController.initFoo` in
  /// package:foo (see devtools_extensions/example/packages_with_extensions/foo/packages/foo/lib/src/foo_controller.dart).
  ///
  /// It is important to note that we are calling the service extension on the
  /// main isolate here using the [serviceManager.callServiceExtensionOnMainIsolate].
  ///
  /// To call a service extension that was registered in a different isolate,
  /// you can use [serviceManager.service.callServiceExtension], but this call
  /// MUST include the isolate id of the isolate that the service extension was
  /// registered in.
  Future<void> _updateSelectedThing(int id) async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.foo.getThing',
        args: {'id': id},
      );
      setState(() {
        selectedThing = response.json?['value'] as String? ?? 'unknown';
      });
    } catch (e) {
      print('error fetching thing $id');
      setState(() {
        selectedThing = 'unknown';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_updateSelectedThing(widget.selectedThingId));
  }

  @override
  void didUpdateWidget(SelectedThing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedThingId != widget.selectedThingId) {
      unawaited(_updateSelectedThing(widget.selectedThingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Selected thing id: ${widget.selectedThingId}'),
            const SizedBox(width: defaultSpacing),
            IconButton.filled(
              onPressed: widget.onIncrement,
              icon: const Icon(Icons.arrow_upward_rounded),
              iconSize: defaultIconSize,
            ),
            const SizedBox(
              width: densePadding,
            ),
            IconButton.filled(
              onPressed: widget.onDecrement,
              icon: const Icon(Icons.arrow_downward_rounded),
              iconSize: defaultIconSize,
            ),
          ],
        ),
        const SizedBox(height: denseSpacing),
        Text('Selected thing value: $selectedThing'),
      ],
    );
  }
}

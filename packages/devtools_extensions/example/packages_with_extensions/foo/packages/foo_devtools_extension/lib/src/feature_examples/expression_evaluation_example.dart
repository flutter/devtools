// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

/// A widget that shows an example of how to perform expression evaluations over
/// the VM Service protocol.
///
/// The expression evaluations are made using [EvalOnDartLibrary], which is a
/// helper class to take a library (e.g. "package:foo/src/foo_controller.dart")
/// and perform Dart expression evaluations over it
/// (e.g. "FooController.instance.things.value.toString()").
///
/// Evaluations can be performed when the app is both paused and unpaused. In
/// contrast, service extension calls can only be made when the app is unpaused
/// (see service_extension_example.dart).
class EvalExample extends StatefulWidget {
  const EvalExample({super.key});

  @override
  State<EvalExample> createState() => _EvalExampleState();
}

class _EvalExampleState extends State<EvalExample> with AutoDisposeMixin {
  late final EvalOnDartLibrary fooControllerEval;
  late final Disposable evalDisposable;

  static const _defaultEvalResponseText = '--';

  var evalResponseText = _defaultEvalResponseText;

  @override
  void initState() {
    super.initState();
    unawaited(_initEval());
  }

  @override
  void dispose() {
    fooControllerEval.dispose();
    evalDisposable.dispose();
    super.dispose();
  }

  Future<void> _initEval() async {
    await serviceManager.onServiceAvailable;
    fooControllerEval = EvalOnDartLibrary(
      'package:foo/src/foo_controller.dart',
      serviceManager.service!,
      serviceManager: serviceManager,
    );
    evalDisposable = Disposable();
  }

  Future<void> _getAllThings() async {
    final ref = await fooControllerEval.evalInstance(
      'FooController.instance.things.value.toString()',
      isAlive: evalDisposable,
    );
    setState(() {
      evalResponseText = ref.valueAsString ?? _defaultEvalResponseText;
    });
  }

  Future<void> _getFavoriteThing() async {
    final ref = await fooControllerEval.evalInstance(
      'FooController.instance.favoriteThing.value',
      isAlive: evalDisposable,
    );
    setState(() {
      evalResponseText = ref.valueAsString ?? _defaultEvalResponseText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'These evaluations can be called when the main isolate is paused and '
          'when it is not.',
          style: theme.subtleTextStyle,
        ),
        const SizedBox(height: denseSpacing),
        Row(
          children: [
            ElevatedButton(
              onPressed: _getAllThings,
              child: const Text('Get all things'),
            ),
            const SizedBox(width: defaultSpacing),
            ElevatedButton(
              onPressed: _getFavoriteThing,
              child: const Text('Get the favorite thing'),
            ),
          ],
        ),
        const SizedBox(height: defaultSpacing),
        const Text('Eval response:'),
        const SizedBox(height: denseSpacing),
        Text(
          evalResponseText,
          style: theme.fixedFontStyle,
        ),
      ],
    );
  }
}

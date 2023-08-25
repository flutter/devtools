// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/widgets.dart';

/// This is an example of a [StatefulWidget] that uses the [AutoDisposeMixin] on
/// its state.
///
/// [AutoDisposeMixin] is exposed by 'package:devtools_app_shared/utils.dart'.
class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({super.key, required this.someNotifier});

  final ValueNotifier<String> someNotifier;

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

// This is a State class that mixes in [AutoDisoposeMixin].
class _MyStatefulWidgetState extends State<MyStatefulWidget>
    with AutoDisposeMixin {
  late final MyController controller;
  late String foo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(MyStatefulWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.someNotifier != widget.someNotifier) {
      _init();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _init() {
    // This kicks off initialization in [controller] which uses the
    // [AutoDisposeControllerMixin].
    controller = MyController(widget.someNotifier)..init();

    // Cancel any existing listeners in situations like this where we could be
    // "re-initializing" in [didUpdateWidget].
    cancelListeners();

    foo = widget.someNotifier.value;

    // Adds a listener to [widget.someNotifier] that will be automatically
    // disposed as part of this stateful widget lifecycle.
    addAutoDisposeListener(widget.someNotifier, () {
      setState(() {
        foo = widget.someNotifier.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(foo);
  }
}

/// This is an example of a controller that uses the
/// [AutoDisposeControllerMixin] exposed by
/// 'package:devtools_app_shared/utils.dart'.
///
/// When [dispose] is called on this controller, any listeners or stream
/// subscriptions added using the [AutoDisposeControllerMixin] will be disposed
/// or canceled.
class MyController extends DisposableController
    with AutoDisposeControllerMixin {
  MyController(this.notifier);

  final ValueNotifier<String> notifier;

  void init() {
    addAutoDisposeListener(notifier, () {
      // Do something.
    });
  }
}

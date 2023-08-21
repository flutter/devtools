// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/widgets.dart';

void main() {
  /// Example: setting and accessing globals.
  setAndAccessGlobal();

  /// Example: [ListValueNotifier]
  useListValueNotifier();
}

MyCoolClass get coolClass => globals[MyCoolClass] as MyCoolClass;

void setAndAccessGlobal() {
  // Creates a globally accessible variable (`globals[ServiceManager]`);
  setGlobal(MyCoolClass, MyCoolClass());
  coolClass.foo();
}

class MyCoolClass {
  void foo() {
    print('foo');
  }
}

void useListValueNotifier() {
  final myListNotifier = ListValueNotifier<int>([1, 2, 3]);
  // These calls will notify all listeners of [myListNotifier].
  myListNotifier.add(4);
  myListNotifier.removeAt(0);
  // ...
}

/// Example: [AutoDisposeMixin]

class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({super.key, required this.someNotifier});

  final ValueNotifier<String> someNotifier;

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

// This is a State class that mixes in [AutoDisoposeMixin].
class _MyStatefulWidgetState extends State<MyStatefulWidget>
    with AutoDisposeMixin {
  late String foo;

  @override
  void initState() {
    super.initState();
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

// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../flutter/controllers.dart';

/// This is an example implementation of a provided controller.
///
/// For any widget in the tree, such that [ExampleControllerProvider] is an
/// ancestor, the inherited [ExampleController] instance can be accessed via
/// `ExampleControllerProvider.of(context)`.
///
/// This class exists solely as an example and should not be used in the
/// DevTools app.
class ExampleController {
  ValueNotifier<String> title = ValueNotifier<String>('');

  FutureOr<void> processOfflineData(String offlineData) {
    title.value = offlineData;
  }
}

class ExampleControllerProvider extends ControllerProvider {
  const ExampleControllerProvider({Key key, Widget child})
      : super(key: key, child: child);

  @override
  _ExampleControllerProviderState createState() =>
      _ExampleControllerProviderState();

  static ExampleController of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_InheritedExampleController>();
    return provider?.data;
  }
}

class _ExampleControllerProviderState extends State<ExampleControllerProvider> {
  ExampleController data;

  @override
  void initState() {
    super.initState();
    _initializeProviderData();
  }

  @override
  void didUpdateWidget(ExampleControllerProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeProviderData();
  }

  void _initializeProviderData() {
    data = ExampleController();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedExampleController(data: data, child: widget.child);
  }
}

class _InheritedExampleController extends InheritedWidget {
  const _InheritedExampleController(
      {@required this.data, @required Widget child})
      : super(child: child);

  final ExampleController data;

  @override
  bool updateShouldNotify(_InheritedExampleController oldWidget) =>
      oldWidget.data != data;
}

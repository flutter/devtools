// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals.dart';
import '../screen.dart';

/// This is an example implementation of a conditional screen that supports
/// offline mode and uses a provided controller [ExampleController].
///
/// This class exists solely as an example and should not be used in the
/// DevTools app.
class ExampleConditionalScreen extends Screen {
  const ExampleConditionalScreen()
      : super.conditional(
          id: id,
          requiresLibrary: 'package:flutter/',
          title: 'Example',
          icon: Icons.palette,
        );

  static const id = 'example';

  @override
  Widget build(BuildContext context) {
    return const _ExampleConditionalScreenBody();
  }
}

class _ExampleConditionalScreenBody extends StatefulWidget {
  const _ExampleConditionalScreenBody();

  @override
  _ExampleConditionalScreenBodyState createState() =>
      _ExampleConditionalScreenBodyState();
}

class _ExampleConditionalScreenBodyState
    extends State<_ExampleConditionalScreenBody>
    with OfflineScreenMixin<_ExampleConditionalScreenBody, String> {
  ExampleController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<ExampleController>(context);
    if (newController == controller) return;
    controller = newController;

    if (shouldLoadOfflineData()) {
      final json = offlineDataJson[ExampleConditionalScreen.id];
      if (json.isNotEmpty) {
        loadOfflineData(json['title']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exampleScreen = ValueListenableBuilder(
      valueListenable: controller.title,
      builder: (context, value, _) {
        return Center(child: Text(value));
      },
    );

    // We put these two items in a stack because the screen's UI needs to be
    // built before offline data is processed in order to initialize listeners
    // that respond to data processing events. The spinner hides the screen's
    // empty UI while data is being processed.
    return Stack(
      children: [
        exampleScreen,
        if (loadingOfflineData)
          Container(
            color: Colors.grey[50],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  @override
  FutureOr<void> processOfflineData(String offlineData) async {
    await controller.processOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[ExampleConditionalScreen.id] != null;
  }
}

class ExampleController {
  final ValueNotifier<String> title = ValueNotifier('Example screen');

  FutureOr<void> processOfflineData(String offlineData) {
    title.value = offlineData;
  }
}

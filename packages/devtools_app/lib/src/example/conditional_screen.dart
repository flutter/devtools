// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import '../shared/screen.dart';
import '../shared/utils.dart';

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
    with
        OfflineScreenMixin<_ExampleConditionalScreenBody, String>,
        ProvidedControllerMixin<ExampleController,
            _ExampleConditionalScreenBody> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    if (shouldLoadOfflineData()) {
      final json =
          offlineController.offlineDataJson[ExampleConditionalScreen.id];
      if (json.isNotEmpty) {
        unawaited(loadOfflineData(json['title']));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exampleScreen = ValueListenableBuilder<String>(
      valueListenable: controller.title,
      builder: (context, String value, _) {
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
            child: const CenteredCircularProgressIndicator(),
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
    return offlineController.shouldLoadOfflineData(ExampleConditionalScreen.id);
  }
}

class ExampleController {
  final ValueNotifier<String> title = ValueNotifier('Example screen');

  FutureOr<void> processOfflineData(String offlineData) {
    title.value = offlineData;
  }
}

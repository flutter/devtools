// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../shared/globals.dart';
import '../shared/offline_data.dart';
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
          worksWithOfflineData: true,
        );

  static const id = 'example';

  @override
  Widget buildScreenBody(BuildContext context) {
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
        ProvidedControllerMixin<ExampleController,
            _ExampleConditionalScreenBody> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ExampleScreenData>(
      valueListenable: controller.data,
      builder: (context, data, _) {
        return Center(child: Text(data.title));
      },
    );
  }
}

class ExampleController extends DisposableController
    with
        AutoDisposeControllerMixin,
        OfflineScreenControllerMixin<ExampleScreenData> {
  ExampleController() {
    unawaited(_init());
  }

  final data =
      ValueNotifier<ExampleScreenData>(ExampleScreenData('Example screen'));

  final _initialized = Completer<void>();

  Future<void> get initialized => _initialized.future;

  Future<void> _init() async {
    await _initHelper();
    _initialized.complete();
  }

  Future<void> _initHelper() async {
    if (!offlineDataController.showingOfflineData.value) {
      // Do some initialization for online mode.
    } else {
      await maybeLoadOfflineData(
        ExampleConditionalScreen.id,
        createData: (json) => ExampleScreenData.parse(json),
        shouldLoad: (data) => data.title.isNotEmpty,
      );
    }
  }

  // Overrides for [OfflineScreenControllerMixin]

  @override
  FutureOr<void> processOfflineData(ExampleScreenData offlineData) {
    data.value = offlineData;
  }

  @override
  OfflineScreenData prepareOfflineScreenData() {
    return OfflineScreenData(
      screenId: ExampleConditionalScreen.id,
      data: data.value.json,
    );
  }
}

class ExampleScreenData {
  ExampleScreenData(this.title);

  factory ExampleScreenData.parse(Map<String, Object?> json) {
    return ExampleScreenData(json[_titleKey] as String);
  }

  static const _titleKey = 'title';

  final String title;

  Map<String, Object?> get json => {_titleKey: title};
}

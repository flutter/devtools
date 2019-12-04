// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../globals.dart';
import '../service_registrations.dart' as registrations;
import '../version.dart';

// TODO(kenz): we should listen for flag value updates and update the info
// screen with the new flag values. See
// https://github.com/flutter/devtools/issues/988.

typedef OnFlutterVersionChanged = void Function(FlutterVersion version);

typedef OnFlagListChanged = void Function(FlagList flagList);

class InfoController extends DisposableController
    with AutoDisposeControllerMixin {
  InfoController({
    @required this.onFlutterVersionChanged,
    @required this.onFlagListChanged,
  });

  final OnFlutterVersionChanged onFlutterVersionChanged;

  final OnFlagListChanged onFlagListChanged;

  final flutterVersionServiceAvailable = Completer();

  Future<void> entering() async {
    onFlagListChanged(await serviceManager.service.getFlagList());
    await _listenForFlutterVersionChanges();
  }

  Future<void> _listenForFlutterVersionChanges() async {
    if (await serviceManager.connectedApp.isAnyFlutterApp) {
      final flutterVersionServiceListenable = serviceManager
          .registeredServiceListenable(registrations.flutterVersion.service);
      addAutoDisposeListener(flutterVersionServiceListenable, () async {
        final serviceAvailable = flutterVersionServiceListenable.value;
        if (serviceAvailable && !flutterVersionServiceAvailable.isCompleted) {
          flutterVersionServiceAvailable.complete();
          final FlutterVersion version = FlutterVersion.parse(
              (await serviceManager.getFlutterVersion()).json);
          onFlutterVersionChanged(version);
        } else {
          onFlutterVersionChanged(null);
        }
      });
    } else {
      onFlutterVersionChanged(null);
    }
  }
}

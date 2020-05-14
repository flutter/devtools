// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../globals.dart';
import '../service_registrations.dart' as registrations;
import '../version.dart';

typedef OnFlutterVersionChanged = void Function(FlutterVersion version);

typedef OnFlagListChanged = void Function(FlagList flagList);

class InfoController extends DisposableController
    with AutoDisposeControllerMixin {
  InfoController({
    @required this.onFlutterVersionChanged,
    this.onFlagListChanged,
  });

  final OnFlutterVersionChanged onFlutterVersionChanged;

  final OnFlagListChanged onFlagListChanged;

  final flutterVersionServiceAvailable = Completer();

  ValueNotifier<FlagList> get flagListNotifier =>
      serviceManager.vmFlagManager.flags;

  Future<void> entering() async {
    // Once the html app is deleted, this code and the [onFlagListChanged] var
    // can be removed. The flutter version of DevTools listens to [flagNotifier]
    // for changes.
    if (onFlagListChanged != null) {
      onFlagListChanged(await serviceManager.service.getFlagList());
    }
    await _listenForFlutterVersionChanges();
  }

  Future<void> _listenForFlutterVersionChanges() async {
    if (await serviceManager.connectedApp.isFlutterApp) {
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

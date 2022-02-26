// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/auto_dispose.dart';
import '../service/service_registrations.dart' as registrations;
import '../shared/globals.dart';
import '../shared/version.dart';

class InfoController extends DisposableController
    with AutoDisposeControllerMixin {
  InfoController() {
    _listenForFlutterVersionChanges();
  }

  /// Return the FlutterVersion for the current connected app, or `null`
  /// if the `flutterVersion` service extension does not exist.
  static Future<FlutterVersion?> getFlutterVersion() async {
    final app = serviceManager.connectedApp!;
    if (!(await app.isFlutterApp)) {
      return null;
    }

    return serviceManager.flutterVersion.then((response) {
      // The cast is needed to return null in case of error.
      // ignore: unnecessary_cast
      return FlutterVersion.parse(response.json!) as FlutterVersion?;
    }).catchError((e) => null);
  }

  final flutterVersionServiceAvailable = Completer();

  ValueListenable<FlutterVersion?> get flutterVersion => _flutterVersion;

  final _flutterVersion = ValueNotifier<FlutterVersion?>(null);

  ValueNotifier<FlagList?> get flagListNotifier =>
      serviceManager.vmFlagManager.flags as ValueNotifier<FlagList?>;

  Future<void> _listenForFlutterVersionChanges() async {
    if (serviceManager.connectedApp!.isFlutterAppNow!) {
      final flutterVersionServiceListenable = serviceManager
          .registeredServiceListenable(registrations.flutterVersion.service);
      addAutoDisposeListener(flutterVersionServiceListenable, () async {
        final serviceAvailable = flutterVersionServiceListenable.value;
        if (serviceAvailable && !flutterVersionServiceAvailable.isCompleted) {
          flutterVersionServiceAvailable.complete();
          final FlutterVersion version =
              FlutterVersion.parse((await serviceManager.flutterVersion).json!);
          _flutterVersion.value = version;
        } else {
          _flutterVersion.value = null;
        }
      });
    } else {
      _flutterVersion.value = null;
    }
  }
}

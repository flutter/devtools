// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:flutter/foundation.dart';

import '../../service/service_extensions.dart' as extensions;
import '../globals.dart';
import '../primitives/utils.dart';

/// Enables or disables HTTP logging for all isolates.
Future<void> toggleHttpRequestLogging(bool state) async {
  await serviceConnection.serviceManager.service!
      .forEachIsolate((isolate) async {
    final httpLoggingAvailable = await serviceConnection.serviceManager.service!
        .isHttpTimelineLoggingAvailableWrapper(isolate.id!);
    if (httpLoggingAvailable) {
      final future = serviceConnection.serviceManager.service!
          .httpEnableTimelineLoggingWrapper(
        isolate.id!,
        state,
      );
      // The above call won't complete immediately if the isolate is paused, so
      // give up waiting after 500ms. However, the call will complete eventually
      // if the isolate is eventually resumed.
      // TODO(jacobr): detect whether the isolate is paused using the vm
      // service and handle this case gracefully rather than timing out.
      await timeout(future, 500);
    }
  });
}

bool get httpLoggingEnabled => httpLoggingState.value.enabled;

ValueListenable<ServiceExtensionState> get httpLoggingState =>
    serviceConnection.serviceManager.serviceExtensionManager
        .getServiceExtensionState(
      extensions.httpEnableTimelineLogging.extension,
    );

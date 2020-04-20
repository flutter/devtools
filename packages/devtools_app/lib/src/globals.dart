// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'core/message_bus.dart';
import 'service_manager.dart';

/// Snapshot mode is an offline mode where DevTools can operate on an imported
/// data file.
bool offlineMode = false;

// TODO(kenz): store this data in an inherited widget.
Map<String, dynamic> offlineDataJson = {};

final Map<Type, dynamic> globals = <Type, dynamic>{};

ServiceConnectionManager get serviceManager =>
    globals[ServiceConnectionManager];

MessageBus get messageBus => globals[MessageBus];

void setGlobal(Type clazz, dynamic instance) {
  globals[clazz] = instance;
}

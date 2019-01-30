// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'ui/icons.dart';

class RegisteredServiceDescription {
  const RegisteredServiceDescription._({
    this.service,
    this.title,
    this.icon,
  });

  final String service;
  final String title;
  final Icon icon;
}

// Service registered by Flutter Tools. We call this service to perform hot
// reload.
const RegisteredServiceDescription hotReload = RegisteredServiceDescription._(
  service: 'reloadSources',
  title: 'Hot Reload',
  icon: FlutterIcons.hotReload,
);

// Service registered by Flutter Tools. We call this service to perform hot
// restart.
const RegisteredServiceDescription hotRestart = RegisteredServiceDescription._(
  service: 'hotRestart',
  title: 'Hot Restart',
  icon: FlutterIcons.hotRestart,
);

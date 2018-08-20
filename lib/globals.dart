// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'service.dart';

final Map<Type, dynamic> globals = <Type, dynamic>{};

ServiceConnectionManager get serviceInfo => globals[ServiceConnectionManager];

void setGlobal(Type clazz, dynamic instance) {
  globals[clazz] = instance;
}

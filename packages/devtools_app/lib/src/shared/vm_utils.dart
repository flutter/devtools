// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

bool isPrimativeInstanceKind(String? kind) {
  return kind == InstanceKind.kBool ||
      kind == InstanceKind.kDouble ||
      kind == InstanceKind.kInt ||
      kind == InstanceKind.kNull ||
      kind == InstanceKind.kString;
}

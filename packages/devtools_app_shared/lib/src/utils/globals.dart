// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

final Map<Type, Object> globals = <Type, Object>{};

void setGlobal(Type clazz, Object instance) {
  globals[clazz] = instance;
}

void removeGlobal(Type clazz) {
  globals.remove(clazz);
  assert(globals[clazz] == null);
}

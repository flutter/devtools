// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

final globals = <Type, Object>{};

void setGlobal(Type clazz, Object instance) {
  globals[clazz] = instance;
}

void removeGlobal(Type clazz) {
  globals.remove(clazz);
  assert(globals[clazz] == null);
}

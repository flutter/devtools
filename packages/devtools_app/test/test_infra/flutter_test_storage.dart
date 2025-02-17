// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/primitives/storage.dart';

/// A [Storage] implementation that does not store state between instances.
///
/// This ephemeral implementation is meant to help keep unit tests segregated
class FlutterTestStorage implements Storage {
  late final values = <String, dynamic>{};

  @override
  Future<String?> getValue(String key) async {
    return values[key];
  }

  @override
  Future<void> setValue(String key, String value) async {
    values[key] = value;
  }
}

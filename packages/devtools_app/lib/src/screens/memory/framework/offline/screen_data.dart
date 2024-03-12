// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum _JsonFields {
  helloWorld,
}

/// Data for the Memory screen when the app is offline.
class MemoryScreenOfflineData {
  MemoryScreenOfflineData();

  MemoryScreenOfflineData.fromJson(Map<String, dynamic> json)
      : assert(
            json[_JsonFields.helloWorld.name] == _JsonFields.helloWorld.name);

  Map<String, dynamic> toJson() => {
        _JsonFields.helloWorld.name: _JsonFields.helloWorld.name,
      };
}

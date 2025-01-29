// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppLinkSettings.fromJson', () {
    final appLinkSettings = AppLinkSettings.fromJson('''{
  "deeplinks": [
    {
      "scheme": "https",
      "host": "example.com",
      "path": "/path1",
      "intentFilterCheck": {
        "hasBrowsableCategory": false,
        "hasActionView": true,
        "hasDefaultCategory": true,
        "hasAutoVerify": true
      }
    },
    {
      "scheme": "https",
      "host": "example.com",
      "path": "/path2",
      "intentFilterCheck": {
        "hasBrowsableCategory": false,
        "hasActionView": true,
        "hasDefaultCategory": true,
        "hasAutoVerify": true
      }
    }
  ],
  "deeplinkingFlagEnabled": true,
  "applicationId": "com.example.app"
}
''');

    expect(appLinkSettings.applicationId, 'com.example.app');
    expect(appLinkSettings.deeplinkingFlagEnabled, true);
    expect(appLinkSettings.deeplinks.length, 2);
    expect(appLinkSettings.deeplinks[0].path, '/path1');
    expect(
      appLinkSettings.deeplinks[0].intentFilterChecks.hasBrowsableCategory,
      false,
    );
    expect(appLinkSettings.deeplinks[0].intentFilterChecks.hasActionView, true);
    expect(
      appLinkSettings.deeplinks[0].intentFilterChecks.hasDefaultCategory,
      true,
    );
    expect(appLinkSettings.deeplinks[0].intentFilterChecks.hasAutoVerify, true);
  });
}

// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UniversalLinkSettings.fromJson', () {
    final universalLinkSettings = UniversalLinkSettings.fromJson('''
{"bundleIdentifier":"app.id","teamIdentifier":"AAAABBBB","associatedDomains":["example.com"]}
''');

    expect(universalLinkSettings.bundleIdentifier, 'app.id');
    expect(universalLinkSettings.teamIdentifier, 'AAAABBBB');
    expect(universalLinkSettings.associatedDomains.length, 1);
    expect(universalLinkSettings.associatedDomains[0], 'example.com');
  });
}

<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
If macos configuration needs to be regenerated, after regeneration
apply updates to avoide bug like
https://github.com/flutter/devtools/issues/5189

1. Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme:

set `buildConfiguration` to `Release`

2. Runner/DebugProfile.entitlements,
Runner/Release.entitlements:

set `com.apple.security.app-sandbox` to false.

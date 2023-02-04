If macos configuration needs to be regenerated, after regeneration
apply updates to avoide bug like
https://github.com/flutter/devtools/issues/5189

Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme:
set `buildConfiguration` to `Release`

Runner/DebugProfile.entitlements,
Runner/Release.entitlements:
set `com.apple.security.app-sandbox` to false.

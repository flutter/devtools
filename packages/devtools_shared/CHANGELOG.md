# 3.0.2

- Bump `package:extension_discovery` version to ^2.0.0

# 3.0.1

- Bump `package:extension_discovery` version to ^1.0.1

# 3.0.0

- Separate extension-related libraries into those that require `dart:io` (exported as
`devtools_extensions_io.dart`) and those that do not (exported as `devtools_extensions.dart`).

Prior to version 3.0.0, `package:devtools_shared` was versioned in lockstep with
`package:devtools_app`. Both of these packages are developed as part of the broader
[DevTools project](https://github.com/flutter/devtools). To see changes and commits
for `package:devtools_shared`, prior to version 3.0.0 please view the git log
[here](https://github.com/flutter/devtools/commits/master/packages/devtools_shared).

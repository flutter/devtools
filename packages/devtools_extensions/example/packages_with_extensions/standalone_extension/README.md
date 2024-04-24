# standalone_extension

An example DevTools extension for `package:standalone_extension`, a pure Dart package.
This is a standalone extension, which means this DevTools extension is not a companion
tool for an existing package, but rather is a development tool that can be used on an
arbitrary Dart / Flutter project.

This example also shows an example of an extension that does not require a
running application. The `app_that_uses_foo` project will import this example as a
`dev_dependency`.

For a more interesting example of things you can do with a DevTools extension,
see the example extension for "package:foo" instead.

The source code for the `standalone_extension` Flutter web app lives directly in this
package under `lib/`. The precompiled extension assets also live in this package under
`extension/devtools/build`, which is how `package:standalone_extension` provides the
DevTools extension.

When a user is using DevTools to debug an app that imports `package:standalone_extension`,
likely as a `dev_dependency` since this is a tooling package, the extension that this
package provides will be embedded in DevTools in its own screen.

The full instructions for building DevTools extensions can be found in the main
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_extensions/README.md)
for the `devtools_extensions` package.

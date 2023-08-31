# foo_devtools_extension

An example DevTools extension for `package:foo`. This Flutter web app, `foo_devtools_extension`,
is included with the parent `package:foo` by including its pre-compiled build output in the
`foo/extension/devtools/build` directory.

Then, when using DevTools to debugging an app that imports the parent `package:foo`
(see `devtools_extensions/example/app_that_uses_foo`), the Flutter web app
`foo_devtools_extension` will be embedded in DevTools in its own screen.

The full instructions for building DevTools extensions can be found in the main
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_extensions/README.md) for the `devtools_extensions` package.

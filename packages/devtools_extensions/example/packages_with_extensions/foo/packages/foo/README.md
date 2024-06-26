# package:foo

This is an example package that has a DevTools extension shipped with it.
See the `extension/devtools` directory. There you will find the two requirements
for the parent package that is providing a DevTools extension:
1. A `config.yaml` file that contains metadata DevTools needs to load the extension.
2. The `build` directory, which contains the pre-compiled build output of the
extension Flutter web app (see `foo/packages/foo_devtools_extension`).

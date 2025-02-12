<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
# package:foo

This is an example package that has a DevTools extension shipped with it.
See the `extension/devtools` directory. There you will find the two requirements
for the parent package that is providing a DevTools extension:
1. A `config.yaml` file that contains metadata DevTools needs to load the extension.
2. The `build` directory, which contains the pre-compiled build output of the
extension Flutter web app (see `foo/packages/foo_devtools_extension`).

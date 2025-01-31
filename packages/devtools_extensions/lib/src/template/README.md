<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
The code in this directory is for the DevTools extension template that package
authors will use to build DevTools extensions. Files in this directory are
exported through the `lib/devtools_extensions.dart` file.

This code is not intended to be imported into DevTools itself. Anything that
should be shared between DevTools and DevTools extensions will be under the
`src/api` directory and exported through `lib/api.dart`.

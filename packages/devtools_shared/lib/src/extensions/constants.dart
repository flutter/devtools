// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Location where DevTools extension assets will be served, relative to where
/// DevTools assets are served (build/).
const extensionRequestPath = 'devtools_extensions';

/// The name of the options file where extension enablement states are stored
/// in a user's project.
const devtoolsOptionsFileName = 'devtools_options.yaml';

/// The depth to search the user's IDE workspace roots for projects with
/// DevTools extensions.
///
/// We use a larger depth than the default to reduce the risk of missing
/// static extensions in the user's project.
const staticExtensionsSearchDepth = 8;

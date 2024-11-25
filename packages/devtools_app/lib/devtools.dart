// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The DevTools application version
///
/// This version should only be updated by running the 'dt update-version'
/// command that updates the version here and in 'devtools_app/pubspec.yaml'.
///
/// Note: a regexp in the `dt update-version' command logic matches the constant
/// declaration `const version =`. If you change the declaration you must also
/// modify the regex in the `dt update-version' command logic.
const version = '2.41.0-dev.4';

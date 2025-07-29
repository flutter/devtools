<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->

# inspector_app

App for running DevTools integration tests for the Inspector panel.

## `main.dart`

Contains an app built with widgets from the test_infra/fixtures/custom_widgets
widget library which is used by the Inspector integration test to verify that
the implementation are displayed correctly in the widget tree.

## `overflow_errors.dart`

Contains an app which includes overflow errors which is used by the Inspector
integration test to verify that those errors are displayed correctly in the
widget tree.

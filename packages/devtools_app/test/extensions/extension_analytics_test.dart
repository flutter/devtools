// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/analytics/constants.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/test_data/extensions.dart';

void main() {
  group('DevTools extension analytics', () {
    test(
      'uses extension name for public package',
      () {
        final public = providerExtension;
        expect(public.isPubliclyHosted, true);
        expect(public.name, 'provider');
        expect(public.analyticsSafeName, 'provider');
        expect(
          DevToolsExtensionEvents.extensionScreenName(public),
          'extension-provider',
        );
        expect(
          DevToolsExtensionEvents.extensionFeedback(public),
          'extensionFeedback-provider',
        );
        expect(
          DevToolsExtensionEvents.extensionEnableManual(public),
          'extensionEnable-manual-provider',
        );
        expect(
          DevToolsExtensionEvents.extensionEnablePrompt(public),
          'extensionEnable-prompt-provider',
        );
        expect(
          DevToolsExtensionEvents.extensionDisableManual(public),
          'extensionDisable-manual-provider',
        );

        expect(
          DevToolsExtensionEvents.extensionDisablePrompt(public),
          'extensionDisable-prompt-provider',
        );
        expect(
          DevToolsExtensionEvents.extensionForceReload(public),
          'extensionForceReload-provider',
        );
      },
    );

    test(
      'does not use extension name for private package',
      () {
        final private = fooExtension;
        expect(private.isPubliclyHosted, false);
        expect(private.name, 'Foo');
        expect(private.analyticsSafeName, 'private');
        expect(
          DevToolsExtensionEvents.extensionScreenName(private),
          'extension-private',
        );
        expect(
          DevToolsExtensionEvents.extensionFeedback(private),
          'extensionFeedback-private',
        );
        expect(
          DevToolsExtensionEvents.extensionEnableManual(private),
          'extensionEnable-manual-private',
        );
        expect(
          DevToolsExtensionEvents.extensionEnablePrompt(private),
          'extensionEnable-prompt-private',
        );
        expect(
          DevToolsExtensionEvents.extensionDisableManual(private),
          'extensionDisable-manual-private',
        );

        expect(
          DevToolsExtensionEvents.extensionDisablePrompt(private),
          'extensionDisable-prompt-private',
        );
        expect(
          DevToolsExtensionEvents.extensionForceReload(private),
          'extensionForceReload-private',
        );
      },
    );
  });
}

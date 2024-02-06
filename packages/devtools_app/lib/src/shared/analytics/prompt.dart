// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../config_specific/launch_url/launch_url.dart';
import '../utils.dart';
import 'analytics_controller.dart';

/// Conditionally displays a prompt to request permission for collection of
/// usage analytics.
class AnalyticsPrompt extends StatefulWidget {
  const AnalyticsPrompt({super.key, required this.child});

  final Widget child;

  @override
  State<AnalyticsPrompt> createState() => _AnalyticsPromptState();
}

class _AnalyticsPromptState extends State<AnalyticsPrompt>
    with ProvidedControllerMixin<AnalyticsController, AnalyticsPrompt> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ValueListenableBuilder<bool>(
      valueListenable: controller.shouldPrompt,
      builder: (context, showPrompt, child) {
        // Confirm with package:unified_analytics that the consent
        // message has been shown so that devtools can be onboarded
        // into the config file
        // ~/.dart-tool/dart-flutter-telemetry.config
        if (showPrompt) unawaited(controller.confirmConsentMessageShown());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPrompt) child!,
            Expanded(child: widget.child),
          ],
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
          side: BorderSide(
            color: theme.focusColor,
          ),
        ),
        color: theme.canvasColor,
        margin: const EdgeInsets.only(bottom: denseSpacing),
        child: Padding(
          padding: const EdgeInsets.all(defaultSpacing),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send usage statistics for DevTools?',
                    style: textTheme.headlineSmall,
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.close),
                    onPressed: controller.hidePrompt,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: defaultSpacing),
              ),
              _analyticsDescription(textTheme),
              const SizedBox(height: denseRowSpacing),
              _actionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _analyticsDescription(TextTheme textTheme) {
    final consentMessageRegExpResults =
        parseAnalyticsConsentMessage(controller.consentMessage);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: consentMessageRegExpResults[0],
            style: textTheme.titleMedium,
          ),
          TextSpan(
            text: consentMessageRegExpResults[1],
            style:
                textTheme.titleMedium?.copyWith(color: const Color(0xFF54C1EF)),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                unawaited(
                  launchUrl(
                    consentMessageRegExpResults[1],
                  ),
                );
              },
          ),
          TextSpan(
            text: consentMessageRegExpResults[2],
            style: textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () {
            // This will also hide the prompt.
            unawaited(controller.toggleAnalyticsEnabled(false));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: const Text('No thanks.'),
        ),
        const Padding(
          padding: EdgeInsets.only(left: defaultSpacing),
        ),
        ElevatedButton(
          onPressed: () {
            unawaited(controller.toggleAnalyticsEnabled(true));
            controller.hidePrompt();
          },
          child: const Text('Sounds good!'),
        ),
      ],
    );
  }
}

/// This method helps to parse the consent message from
/// `package:unified_analytics` so that the URL can be
/// separated from the block of text so that we can have a
/// hyperlink in the displayed consent message.
List<String> parseAnalyticsConsentMessage(String consentMessage) {
  final results = <String>[];
  final RegExp pattern =
      RegExp(r'^([\S\s]*)(https?:\/\/[^\s]+)(\)\.)$', multiLine: true);

  pattern.allMatches(consentMessage).first.groups([1, 2, 3]).forEach((element) {
    results.add(element!);
  });

  return results;
}

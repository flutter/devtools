// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../common_widgets.dart';
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
    return ValueListenableBuilder<bool>(
      valueListenable: controller.shouldPrompt,
      builder: (context, showPrompt, child) {
        // Mark the consent message as shown for unified_analytics so that devtools
        // can be onboarded into the config file
        // ~/.dart-tool/dart-flutter-telemetry.config
        if (showPrompt) unawaited(controller.markConsentMessageAsShown());

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
                    style: theme.boldTextStyle,
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: actionsIconSize),
                    onPressed: controller.hidePrompt,
                  ),
                ],
              ),
              const SizedBox(height: denseSpacing),
              _analyticsDescription(theme),
              const SizedBox(height: defaultSpacing),
              _actionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _analyticsDescription(ThemeData theme) {
    final consentMessageRegExpResults =
        parseAnalyticsConsentMessage(controller.consentMessage)
            ?.map((e) => adjustLineBreaks(e))
            .toList();

    // When failing to parse the consent message, fallback to displaying the
    // consent message in its regular form.
    if (consentMessageRegExpResults == null) {
      return SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: adjustLineBreaks(controller.consentMessage),
              style: theme.regularTextStyle,
            ),
          ],
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: consentMessageRegExpResults[0],
            style: theme.regularTextStyle,
          ),
          LinkTextSpan(
            link: GaLink(
              display: consentMessageRegExpResults[1],
              url: consentMessageRegExpResults[1],
            ),
            context: context,
            style: theme.linkTextStyle,
          ),
          TextSpan(
            text: consentMessageRegExpResults[2],
            style: theme.regularTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DevToolsButton(
          label: 'No thanks',
          onPressed: () {
            // This will also hide the prompt.
            unawaited(controller.toggleAnalyticsEnabled(false));
          },
        ),
        const SizedBox(width: defaultSpacing),
        DevToolsButton(
          label: 'Sounds good!',
          elevated: true,
          onPressed: () {
            unawaited(controller.toggleAnalyticsEnabled(true));
            controller.hidePrompt();
          },
        ),
      ],
    );
  }
}

/// This method helps to parse the consent message from
/// `package:unified_analytics` so that the URL can be
/// separated from the block of text so that we can have a
/// hyperlink in the displayed consent message.
@visibleForTesting
List<String>? parseAnalyticsConsentMessage(String consentMessage) {
  final results = <String>[];
  final pattern =
      RegExp(r'^([\S\s]*)(https?:\/\/[^\s]+)(\)\.)$', multiLine: true);

  final matches = pattern.allMatches(consentMessage);
  if (matches.isEmpty) {
    return null;
  }

  matches.first.groups([1, 2, 3]).forEach((element) {
    results.add(element!);
  });

  // There should be 3 groups returned if correctly parsed, one
  // for most of the text, one for the URL, and one for what comes
  // after the URL
  if (results.length != 3) {
    return null;
  }

  return results;
}

/// Replaces single line breaks with spaces so that the text [value] can be
/// displayed in a responsive UI and does not have fixed line breaks that do not
/// match the width of the view.
@visibleForTesting
String adjustLineBreaks(String value) {
  final pattern =
      RegExp(r'(?<!\r\n|\r|\n)(\r\n|\r|\n)(?!\r\n|\r|\n)', multiLine: true);
  return value.replaceAll(pattern, ' ');
}

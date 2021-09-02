// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common_widgets.dart';
import '../config_specific/launch_url/launch_url.dart';
import '../theme.dart';
import 'analytics_controller.dart';

/// Conditionally displays a prompt to request permission for collection of
/// usage analytics.
class AnalyticsPrompt extends StatefulWidget {
  const AnalyticsPrompt({@required this.child});

  final Widget child;

  @override
  State<AnalyticsPrompt> createState() => _AnalyticsPromptState();
}

class _AnalyticsPromptState extends State<AnalyticsPrompt> {
  AnalyticsController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newAnalyticsController = Provider.of<AnalyticsController>(context);
    if (newAnalyticsController == _controller) return;
    _controller = newAnalyticsController;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return ValueListenableBuilder(
      valueListenable: _controller.shouldPrompt,
      builder: (context, showPrompt, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPrompt)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(defaultBorderRadius),
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
                            style: textTheme.headline5,
                          ),
                          CircularIconButton(
                            icon: Icons.close,
                            onPressed: _controller.hidePrompt,
                            backgroundColor: theme.canvasColor,
                            foregroundColor:
                                theme.colorScheme.contrastForeground,
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
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }

  Widget _analyticsDescription(TextTheme textTheme) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'DevTools reports feature usage statistics and basic '
                'crash reports to Google in order to help Google improve '
                'the tool over time. See Google\'s ',
            style: textTheme.subtitle1,
          ),
          TextSpan(
            text: 'privacy policy',
            style: textTheme.subtitle1.copyWith(color: const Color(0xFF54C1EF)),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                launchUrl(
                  'https://www.google.com/intl/en/policies/privacy',
                  context,
                );
              },
          ),
          TextSpan(
            text: '.',
            style: textTheme.subtitle1,
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
            _controller.toggleAnalyticsEnabled(false);
          },
          style: ElevatedButton.styleFrom(primary: Colors.grey),
          child: const Text('No thanks.'),
        ),
        const Padding(
          padding: EdgeInsets.only(left: defaultSpacing),
        ),
        ElevatedButton(
          onPressed: () {
            _controller
              ..toggleAnalyticsEnabled(true)
              ..hidePrompt();
          },
          child: const Text('Sounds good!'),
        ),
      ],
    );
  }
}

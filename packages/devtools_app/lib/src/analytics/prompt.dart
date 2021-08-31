// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common_widgets.dart';
import '../config_specific/launch_url/launch_url.dart';
import '../theme.dart';
import 'provider.dart';

/// Conditionally displays a prompt to request permission for collection of
/// usage analytics and manages initializing GTags analytics.
class AnalyticsPrompt extends StatefulWidget {
  const AnalyticsPrompt({@required this.child});

  final Widget child;

  @override
  State<AnalyticsPrompt> createState() => _AnalyticsPromptState();
}

class _AnalyticsPromptState extends State<AnalyticsPrompt> {
  AnalyticsProvider _provider;

  bool _isVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newAnalyticsProvider = Provider.of<AnalyticsProvider>(context);
    if (newAnalyticsProvider == _provider) return;
    _provider = newAnalyticsProvider;

    if (_provider.shouldPrompt.value) {
      // Enable the analytics and give the user the option to opt out via the
      // prompt.
      _provider.enableAnalytics();
      _isVisible = true;
    }
    if (_provider.analyticsEnabled.value) {
      _provider.setUpAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isVisible)
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
                        onPressed: _onPromptClosed,
                        backgroundColor: theme.canvasColor,
                        foregroundColor: theme.colorScheme.contrastForeground,
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
            _provider.disableAnalytics();
            setState(() {
              _isVisible = false;
            });
          },
          style: ElevatedButton.styleFrom(primary: Colors.grey),
          child: const Text('No thanks.'),
        ),
        const Padding(
          padding: EdgeInsets.only(left: defaultSpacing),
        ),
        ElevatedButton(
          onPressed: () {
            _provider.enableAnalytics();
            setState(() {
              _isVisible = false;
            });
          },
          child: const Text('Sounds good!'),
        ),
      ],
    );
  }

  void _onPromptClosed() {
    setState(() {
      _isVisible = false;
    });
  }
}

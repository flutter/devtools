// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils.dart';
import 'provider.dart';

/// Conditionally displays a prompt to request permission for collection of
/// usage analytics.
class AnalyticsPrompt extends StatefulWidget {
  const AnalyticsPrompt({
    @required this.provider,
    @required this.child,
  });

  final Widget child;
  final AnalyticsProvider provider;

  @override
  State<AnalyticsPrompt> createState() =>
      _AnalyticsPromptState(provider, child);
}

class _AnalyticsPromptState extends State<AnalyticsPrompt> {
  _AnalyticsPromptState(this._provider, this._child);

  final Widget _child;
  final AnalyticsProvider _provider;

  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    if (_provider.isGtagsEnabled) {
      if (_provider.shouldPrompt) {
        _isVisible = true;
      } else if (_provider.isEnabled) {
        _provider.setUpAnalytics();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isVisible)
          Card(
            margin: const EdgeInsets.only(bottom: denseRowSpacing),
            child: Padding(
              padding: const EdgeInsets.all(defaultSpacing),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send usage statistics for DevTools?',
                    style: textTheme.headline5,
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
        Expanded(child: _child),
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
            style: textTheme.bodyText1,
          ),
          TextSpan(
            text: 'privacy policy',
            style: const TextStyle(color: Color(0xFF54C1EF)),
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
            style: textTheme.bodyText1,
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RaisedButton(
          child: const Text('No thanks.'),
          onPressed: () {
            _provider.setDontAllowAnalytics();
            setState(() {
              _isVisible = false;
            });
          },
          color: Colors.grey,
        ),
        const Padding(
          padding: EdgeInsets.only(left: defaultSpacing),
        ),
        RaisedButton(
          child: const Text('Sounds good!'),
          onPressed: () {
            _provider.setAllowAnalytics();
            setState(() {
              _isVisible = false;
            });
          },
        ),
      ],
    );
  }
}

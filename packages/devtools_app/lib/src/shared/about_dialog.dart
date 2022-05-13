// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../devtools.dart' as devtools;
import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import 'common_widgets.dart';
import 'dialogs.dart';
import 'globals.dart';
import 'scaffold.dart';
import 'theme.dart';

class DevToolsAboutDialog extends StatelessWidget {
  static const _discordChannelLink =
      'https://discord.com/channels/608014603317936148/958862085297672282';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: dialogTitleText(theme, 'About DevTools'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aboutDevTools(context),
          const SizedBox(height: defaultSpacing),
          ...dialogSubHeader(theme, 'Feedback'),
          Wrap(
            children: [
              const Text('Encountered an issue? Let us know at '),
              _createFeedbackLink(context),
              const Text(','),
            ],
          ),
          Wrap(
            children: [
              const Text('or connect with us on '),
              RichText(
                text: LinkTextSpan(
                  link: const Link(
                    display: 'Discord',
                    url: _discordChannelLink,
                  ),
                  context: context,
                  onTap: () {
                    ga.select(
                      analytics_constants.devToolsMain,
                      analytics_constants.discordLink,
                    );
                  },
                ),
              ),
              const Text('.'),
            ],
          )
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }

  Widget _aboutDevTools(BuildContext context) {
    return const SelectableText('DevTools version ${devtools.version}');
  }

  Widget _createFeedbackLink(BuildContext context) {
    return RichText(
      text: LinkTextSpan(
        link: devToolsExtensionPoints.issueTrackerLink(),
        context: context,
        onTap: () {
          ga.select(
            analytics_constants.devToolsMain,
            analytics_constants.feedbackLink,
          );
        },
      ),
    );
  }
}

class OpenAboutAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: 'About DevTools',
      child: InkWell(
        onTap: () async {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => DevToolsAboutDialog(),
            ),
          );
        },
        child: Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          child: Icon(
            Icons.help_outline,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: dialogTitleText(theme, 'About DevTools'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        [
          const SelectableText('DevTools version ${devtools.version}'),
          const SizedBox(height: defaultSpacing),
          ...dialogSubHeader(theme, 'Feedback'),
          Wrap(
            Text('Encountered an issue? Let us know at '),
            _FeedbackLink(),
            Text(','),
          ),
          Wrap(
            Text('or connect with us on '),
            _DiscordLink(),
            Text('.'),
          )
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}

class _FeedbackLink extends StatelessWidget {
  const _FeedbackLink({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

class _DiscordLink extends StatelessWidget {
  const _DiscordLink({Key? key}) : super(key: key);

  static const _channelLink =
      'https://discord.com/channels/608014603317936148/958862085297672282';

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: LinkTextSpan(
        link: const Link(
          display: 'Discord',
          url: _channelLink,
        ),
        context: context,
        onTap: () {
          ga.select(
            analytics_constants.devToolsMain,
            analytics_constants.discordLink,
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
      InkWell(
        onTap: () async {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => DevToolsAboutDialog(),
            ),
          );
        },
        Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          Icon(
            Icons.help_outline,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

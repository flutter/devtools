// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../devtools.dart' as devtools;
import '../analytics/constants.dart' as analytics_constants;
import '../shared/common_widgets.dart';
import '../shared/dialogs.dart';
import '../shared/globals.dart';
import '../shared/theme.dart';
import 'release_notes/release_notes.dart';

class DevToolsAboutDialog extends StatelessWidget {
  const DevToolsAboutDialog(this.releaseNotesController);

  final ReleaseNotesController releaseNotesController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: const DialogTitleText('About DevTools'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SelectableText('DevTools version ${devtools.version}'),
              const Text(' - '),
              InkWell(
                child: Text(
                  'release notes',
                  style: theme.linkTextStyle,
                ),
                onTap: () =>
                    releaseNotesController.toggleReleaseNotesVisible(true),
              ),
            ],
          ),
          const SizedBox(height: defaultSpacing),
          ...dialogSubHeader(theme, 'Feedback'),
          Wrap(
            children: const [
              Text('Encountered an issue? Let us know at '),
              _FeedbackLink(),
              Text(','),
            ],
          ),
          Wrap(
            children: const [
              Text('or connect with us on '),
              _DiscordLink(),
              Text('.'),
            ],
          )
        ],
      ),
      actions: const [
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
          gaScreenName: analytics_constants.devToolsMain,
          gaSelectedItemDescription: analytics_constants.discordLink,
        ),
        context: context,
      ),
    );
  }
}

class OpenAboutAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final releaseNotesController = Provider.of<ReleaseNotesController>(context);
    return DevToolsTooltip(
      message: 'About DevTools',
      child: InkWell(
        onTap: () async {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => DevToolsAboutDialog(releaseNotesController),
            ),
          );
        },
        child: Container(
          width: actionWidgetSize,
          height: actionWidgetSize,
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

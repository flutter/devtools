// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../devtools.dart' as devtools;
import '../shared/analytics/constants.dart' as gac;
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
          const SizedBox(height: denseSpacing),
          Wrap(
            children: const [
              Text('Encountered an issue? Let us know at '),
              _FeedbackLink(),
              Text('.'),
            ],
          ),
          const SizedBox(height: defaultSpacing),
          ...dialogSubHeader(theme, 'Contributing'),
          Wrap(
            children: const [
              Text('Want to contribute to DevTools? Please see our '),
              _ContributingLink(),
              Text(' guide, or '),
            ],
          ),
          Wrap(
            children: const [
              Text('connect with us on '),
              _DiscordLink(),
              Text('.'),
            ],
          ),
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

class _ContributingLink extends StatelessWidget {
  const _ContributingLink({Key? key}) : super(key: key);

  static const _contributingGuideUrl =
      'https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md';

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: LinkTextSpan(
        link: const Link(
          display: 'CONTRIBUTING',
          url: _contributingGuideUrl,
          gaScreenName: gac.devToolsMain,
          gaSelectedItemDescription: gac.contributingLink,
        ),
        context: context,
      ),
    );
  }
}

class _DiscordLink extends StatelessWidget {
  const _DiscordLink({Key? key}) : super(key: key);

  static const _discordWikiUrl = 'https://github.com/flutter/flutter/wiki/Chat';

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: LinkTextSpan(
        link: const Link(
          display: 'Discord',
          url: _discordWikiUrl,
          gaScreenName: gac.devToolsMain,
          gaSelectedItemDescription: gac.discordLink,
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

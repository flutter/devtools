// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../devtools.dart' as devtools;
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import 'release_notes/release_notes.dart';

class DevToolsAboutDialog extends StatelessWidget {
  const DevToolsAboutDialog(this.releaseNotesController, {super.key});

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
          Wrap(
            children: [
              const SelectableText('DevTools version ${devtools.version}'),
              const Text(' - '),
              InkWell(
                child: Text(
                  'release notes',
                  style: theme.linkTextStyle,
                ),
                onTap: () =>
                    unawaited(releaseNotesController.openLatestReleaseNotes()),
              ),
            ],
          ),
          const SizedBox(height: denseSpacing),
          const Wrap(
            children: [
              Text('Encountered an issue? Let us know at '),
              _FeedbackLink(),
              Text('.'),
            ],
          ),
          const SizedBox(height: defaultSpacing),
          ...dialogSubHeader(theme, 'Contributing'),
          const Wrap(
            children: [
              Text('Want to contribute to DevTools? Please see our '),
              _ContributingLink(),
              Text(' guide, or '),
            ],
          ),
          const Wrap(
            children: [
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
  const _FeedbackLink();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: GaLinkTextSpan(
        link: devToolsExtensionPoints.issueTrackerLink(),
        context: context,
      ),
    );
  }
}

class _ContributingLink extends StatelessWidget {
  const _ContributingLink();

  static const _contributingGuideUrl =
      'https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md';

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: GaLinkTextSpan(
        link: const GaLink(
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
  const _DiscordLink();

  static const _discordWikiUrl = 'https://github.com/flutter/flutter/wiki/Chat';

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: GaLinkTextSpan(
        link: const GaLink(
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

class OpenAboutAction extends ScaffoldAction {
  OpenAboutAction({super.key, super.color})
      : super(
          icon: Icons.help_outline,
          tooltip: 'About DevTools',
          onPressed: (context) {
            unawaited(
              showDialog(
                context: context,
                builder: (context) => DevToolsAboutDialog(
                  Provider.of<ReleaseNotesController>(context),
                ),
              ),
            );
          },
        );
}

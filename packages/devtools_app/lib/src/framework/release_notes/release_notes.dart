// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../devtools.dart' as devtools;
import '../../shared/config_specific/server/server.dart' as server;
import '../../shared/side_panel.dart';

final _log = Logger('release_notes');

const debugTestReleaseNotes = false;
const releaseNotesKey = Key('release_notes');

class ReleaseNotesViewer extends SidePanelViewer {
  const ReleaseNotesViewer({
    required super.controller,
    Widget? child,
  }) : super(
          key: releaseNotesKey,
          title: 'What\'s new in DevTools?',
          textIfMarkdownDataEmpty: 'Stay tuned for updates.',
          child: child,
        );
}

class ReleaseNotesController extends SidePanelController {
  ReleaseNotesController() {
    _init();
  }

  static const _unsupportedPathSyntax = '{{site.url}}';

  String get _flutterDocsSite => debugTestReleaseNotes
      ? 'https://flutter-website-dt-staging.web.app'
      : 'https://docs.flutter.dev';

  void _init() {
    if (debugTestReleaseNotes || server.isDevToolsServerAvailable) {
      _maybeFetchReleaseNotes();
    }
  }

  void _maybeFetchReleaseNotes() async {
    SemanticVersion previousVersion = SemanticVersion();
    if (server.isDevToolsServerAvailable) {
      final lastReleaseNotesShownVersion =
          await server.getLastShownReleaseNotesVersion();
      if (lastReleaseNotesShownVersion.isNotEmpty) {
        previousVersion = SemanticVersion.parse(lastReleaseNotesShownVersion);
      }
    }
    // Parse the current version instead of using [devtools.version] directly to
    // strip off any build metadata (any characters following a '+' character).
    // Release notes will be hosted on the Flutter website with a version number
    // that does not contain any build metadata.
    final parsedCurrentVersion = SemanticVersion.parse(devtools.version);
    final parsedCurrentVersionStr = parsedCurrentVersion.toString();
    if (parsedCurrentVersion > previousVersion) {
      try {
        await _fetchReleaseNotes(parsedCurrentVersion);
      } catch (e) {
        // Fail gracefully if we cannot find release notes for the current
        // version of DevTools.
        markdownText = null;
        toggleVisibility(false);
        _log.warning(
          'Warning: could not find release notes for DevTools version '
          '$parsedCurrentVersionStr. $e',
        );
      }
    }
  }

  Future<void> _fetchReleaseNotes(SemanticVersion version) async {
    final currentVersionString = version.toString();

    // Try all patch versions for this major.minor combination until we find
    // release notes (e.g. 2.11.4 -> 2.11.3 -> 2.11.2 -> ...).
    var attempts = version.patch;
    while (attempts >= 0) {
      final versionString = version.toString();
      try {
        String releaseNotesMarkdown = await http.read(
          Uri.parse(_releaseNotesUrl(versionString)),
        );
        // This is a workaround so that the images in release notes will appear.
        // The {{site.url}} syntax is best practices for the flutter website
        // repo, where these release notes are hosted, so we are performing this
        // workaround on our end to ensure the images render properly.
        releaseNotesMarkdown = releaseNotesMarkdown.replaceAll(
          _unsupportedPathSyntax,
          _flutterDocsSite,
        );

        markdownText = releaseNotesMarkdown;
        toggleVisibility(true);
        unawaited(
          server.setLastShownReleaseNotesVersion(currentVersionString),
        );
        return;
      } catch (_) {
        attempts--;
        if (attempts < 0) {
          rethrow;
        }
        version = version.downgrade(downgradePatch: true);
      }
    }
  }

  String _releaseNotesUrl(String currentVersion) {
    return '$_flutterDocsSite/development/tools/devtools/release-notes/'
        'release-notes-$currentVersion-src.md';
  }
}

// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../devtools.dart' as devtools;
import '../../shared/server/server.dart' as server;
import '../../shared/side_panel.dart';

final _log = Logger('release_notes');

// This is not const because it is manipulated for testing as well as for
// local development.
bool debugTestReleaseNotes = false;

// To load markdown from a staged flutter website, set this string to the url
// from the flutter/website PR, which has a GitHub action that automatically
// stages commits to firebase. Example:
// https://flutter-docs-prod--pr8928-dt-notes-links-b0b33er1.web.app/tools/devtools/release-notes/release-notes-2.24.0-src.md.
String? _debugReleaseNotesUrl;

const _flutterDocsSite = 'https://docs.flutter.dev';

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

  void _init() {
    if (debugTestReleaseNotes ||
        _debugReleaseNotesUrl != null ||
        server.isDevToolsServerAvailable) {
      _maybeShowReleaseNotes();
    }
  }

  void _maybeShowReleaseNotes() async {
    SemanticVersion previousVersion = SemanticVersion();
    if (server.isDevToolsServerAvailable) {
      final lastReleaseNotesShownVersion =
          await server.getLastShownReleaseNotesVersion();
      if (lastReleaseNotesShownVersion.isNotEmpty) {
        previousVersion = SemanticVersion.parse(lastReleaseNotesShownVersion);
      }
    }
    await _fetchAndShowReleaseNotes(
      versionFloor: debugTestReleaseNotes ? null : previousVersion,
    );
  }

  /// Fetches and shows the most recent release notes for the current DevTools
  /// version, decreasing the patch version by 1 each time until we find release
  /// notes or until we hit [versionFloor].
  Future<void> _fetchAndShowReleaseNotes({
    SemanticVersion? versionFloor,
  }) async {
    versionFloor ??= SemanticVersion();

    // Parse the current version instead of using [devtools.version] directly to
    // strip off any build metadata (any characters following a '+' character).
    // Release notes will be hosted on the Flutter website with a version number
    // that does not contain any build metadata.
    final parsedVersion = SemanticVersion.parse(devtools.version);
    var notesVersion = latestVersionToCheckForReleaseNotes(parsedVersion);
    try {
      // Try all patch versions for this major.minor combination until we find
      // release notes (e.g. 2.11.4 -> 2.11.3 -> 2.11.2 -> ...).
      final attemptedVersions = <String>[];
      var attempts = notesVersion.patch;
      while (attempts >= 0 && notesVersion > versionFloor) {
        final versionString = notesVersion.toString();
        try {
          String releaseNotesMarkdown = await http.read(
            Uri.parse(_debugReleaseNotesUrl ?? _releaseNotesUrl(versionString)),
          );

          // This is a workaround so that the images in release notes will appear.
          // The {{site.url}} syntax is best practices for the flutter website
          // repo, where these release notes are hosted, so we are performing this
          // workaround on our end to ensure the images render properly.
          releaseNotesMarkdown = releaseNotesMarkdown.replaceAll(
            _unsupportedPathSyntax,
            _flutterDocsSite,
          );

          markdown.value = releaseNotesMarkdown;
          toggleVisibility(true);
          if (_debugReleaseNotesUrl == null &&
              server.isDevToolsServerAvailable) {
            // Only set the last release notes version if we are using a real
            // url and not [_debugReleaseNotesUrl].
            unawaited(
              server.setLastShownReleaseNotesVersion(versionString),
            );
          }
          return;
        } catch (e) {
          attempts--;
          attemptedVersions.add(versionString);
          if (attempts < 0) {
            // ignore: avoid-throw-in-catch-block, false positive
            throw Exception(
              'Could not find release notes for DevTools versions '
              '${attemptedVersions.join(', ')}.'
              '\n$e',
            );
          }
          notesVersion = notesVersion.downgrade(downgradePatch: true);
        }
      }
    } catch (e) {
      // Fail gracefully if we cannot find release notes for the current
      // version of DevTools.
      markdown.value = null;
      toggleVisibility(false);
      _log.warning('Warning: $e');
    }
  }

  @visibleForTesting
  SemanticVersion latestVersionToCheckForReleaseNotes(
    SemanticVersion currentVersion,
  ) {
    // If the current version is a pre-release, downgrade the minor to find the
    // previous DevTools release, and start looking for release notes from this
    // value. Release notes will never be published for pre-release versions.
    if (currentVersion.isPreRelease) {
      // It is very unlikely the patch value of the DevTools version will ever
      // be above this number. This is a safe number to start looking for
      // release notes at.
      const safeStartPatch = 10;
      currentVersion = SemanticVersion(
        major: currentVersion.major,
        minor: currentVersion.minor - 1,
        patch: safeStartPatch,
      );
    }
    return currentVersion;
  }

  Future<void> openLatestReleaseNotes() async {
    if (markdown.value == null) {
      await _fetchAndShowReleaseNotes();
    }
    toggleVisibility(true);
  }

  String _releaseNotesUrl(String currentVersion) {
    return '$_flutterDocsSite/development/tools/devtools/release-notes/'
        'release-notes-$currentVersion-src.md';
  }
}

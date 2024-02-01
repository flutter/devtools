// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

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
const String? _debugReleaseNotesUrl = null;

const releaseNotesKey = Key('release_notes');
const _unsupportedPathSyntax = '{{site.url}}';
const _releaseNotesPath = '/f/devtools-releases.json';
final _flutterDocsSite = Uri.https('docs.flutter.dev');

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
    if (_debugReleaseNotesUrl case final debugUrl?) {
      // Specially handle the case where a debug release notes URL is specified.
      final debugUri = Uri.parse(debugUrl);
      final releaseNotesMarkdown = await http.read(debugUri);

      // Update image links to use debug/testing URL.
      markdown.value = releaseNotesMarkdown.replaceAll(
        _unsupportedPathSyntax,
        debugUri.replace(path: '').toString(),
      );

      toggleVisibility(true);
      return;
    }

    versionFloor ??= SemanticVersion();

    // Parse the current version instead of using [devtools.version] directly to
    // strip off any build metadata (any characters following a '+' character).
    // Release notes will be hosted on the Flutter website with a version number
    // that does not contain any build metadata.
    final parsedVersion = SemanticVersion.parse(devtools.version);
    final notesVersion = latestVersionToCheckForReleaseNotes(parsedVersion);

    if (notesVersion <= versionFloor) {
      // If the current version is equal to or below the version floor,
      // no need to show the release notes.
      _emptyAndClose();
      return;
    }

    final Map<String, Object?> releaseIndex;
    try {
      final releaseIndexUrl = _flutterDocsSite.replace(path: _releaseNotesPath);
      final releaseIndexString = await http.read(releaseIndexUrl);
      releaseIndex = jsonDecode(releaseIndexString) as Map<String, Object?>;
    } catch (e) {
      _emptyAndClose(e.toString());
      return;
    }

    final releases = releaseIndex['releases'];
    if (releases is! Map<String, Object?>) {
      _emptyAndClose(
        'The DevTools release index file was incorrectly formatted.',
      );
      return;
    }

    // If the version floor has the same major and minor version,
    // don't check below its patch version.
    final int minimumPatch;
    if (versionFloor.major == notesVersion.major &&
        versionFloor.minor == notesVersion.minor) {
      minimumPatch = versionFloor.patch;
    } else {
      minimumPatch = 0;
    }

    final majorMinor = '${notesVersion.major}.${notesVersion.minor}';
    var patchToCheck = notesVersion.patch;

    // Try each patch version in this major.minor combination until we find
    // release notes (e.g. 2.11.4 -> 2.11.3 -> 2.11.2 -> ...).
    while (patchToCheck >= minimumPatch) {
      final releaseToCheck = '$majorMinor.$patchToCheck';
      if (releases[releaseToCheck] case final String releaseNotePath) {
        final String releaseNotesMarkdown;
        try {
          releaseNotesMarkdown = await http.read(
            _flutterDocsSite.replace(path: releaseNotePath),
          );
        } catch (_) {
          // If we couldn't retrieve this page, keep going to
          // try with the earlier patch versions.
          continue;
        }

        // Replace the {{site.url}} template syntax that the
        // Flutter docs website uses to specify site URLs.
        markdown.value = releaseNotesMarkdown.replaceAll(
          _unsupportedPathSyntax,
          _flutterDocsSite.toString(),
        );

        toggleVisibility(true);
        if (server.isDevToolsServerAvailable) {
          // Only set the last release notes version
          // if we are not debugging.
          unawaited(
            server.setLastShownReleaseNotesVersion(releaseToCheck),
          );
        }
        return;
      }

      patchToCheck -= 1;
    }

    _emptyAndClose(
      'Could not find release notes for DevTools version $notesVersion.',
    );
    return;
  }

  /// Set the release notes viewer as having no contents, hidden,
  /// and optionally log the specified [message].
  void _emptyAndClose([String? message]) {
    markdown.value = null;
    toggleVisibility(false);
    if (message != null) {
      _log.warning('Warning: $message');
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
}

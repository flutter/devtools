// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../shared/primitives/url_utils.dart';
import '../../shared/server/server.dart' as server;
import '../../shared/side_panel.dart';
import '../../shared/utils.dart';
import '../../standalone_ui/standalone_screen.dart';

final _log = Logger('release_notes');

// This is not const because it is manipulated for testing as well as for
// local development.
bool debugTestReleaseNotes = false;

// To load markdown from a staged flutter website, set this string to the url
// from the flutter/website PR, which has a GitHub action that automatically
// stages commits to firebase. Example:
// https://flutter-docs-prod--pr8928-dt-notes-links-b0b33er1.web.app/tools/devtools/release-notes/release-notes-2.24.0-src.md.
String? _debugReleaseNotesUrl;

const releaseNotesKey = Key('release_notes');
final _baseUrlRelativeMarkdownLinkPattern = RegExp(
  r'(\[.*?]\()(/.*\s*)',
  multiLine: true,
);
const _releaseNotesPath = '/f/devtools-releases.json';
final _flutterDocsSite = Uri.https('docs.flutter.dev');

class ReleaseNotesViewer extends SidePanelViewer {
  const ReleaseNotesViewer({
    required super.controller,
    super.child,
  }) : super(
          key: releaseNotesKey,
          title: 'What\'s new in DevTools?',
          textIfMarkdownDataEmpty: 'Stay tuned for updates.',
        );
}

class ReleaseNotesController extends SidePanelController {
  ReleaseNotesController() {
    _init();
  }

  @visibleForTesting
  static Uri get releaseIndexUrl =>
      _flutterDocsSite.replace(path: _releaseNotesPath);

  void _init() {
    if (debugTestReleaseNotes ||
        _debugReleaseNotesUrl != null ||
        server.isDevToolsServerAvailable) {
      _maybeShowReleaseNotes();
    }
  }

  void _maybeShowReleaseNotes() async {
    final currentUrl = getWebUrl();
    final currentPage =
        currentUrl != null ? extractCurrentPageFromUrl(currentUrl) : null;
    if (isEmbedded() &&
        currentPage == StandaloneScreenType.vsCodeFlutterPanel.name) {
      // Do not show release notes in the Flutter sidebar.
      return;
    }

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

      // Update the base-url-relative links in the file to
      // absolute links using the debug/testing URL.
      markdown.value = _convertBaseUrlRelativeLinks(
        releaseNotesMarkdown,
        debugUri.replace(path: ''),
      );

      toggleVisibility(true);
      return;
    }

    versionFloor ??= SemanticVersion();

    // Parse the current version instead of using [devtools.version] directly to
    // strip off any build metadata (any characters following a '+' character).
    // Release notes will be hosted on the Flutter website with a version number
    // that does not contain any build metadata.
    final parsedVersion = SemanticVersion.parse(devToolsVersion);
    final notesVersion = latestVersionToCheckForReleaseNotes(parsedVersion);

    if (notesVersion <= versionFloor) {
      // If the current version is equal to or below the version floor,
      // no need to show the release notes.
      _emptyAndClose();
      return;
    }

    final releases = await retrieveReleasesFromIndex();
    if (releases == null) {
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
      if (releases[releaseToCheck] case final releaseNotePath?) {
        final String releaseNotesMarkdown;
        try {
          releaseNotesMarkdown = await http.read(
            _flutterDocsSite.replace(path: releaseNotePath),
          );
        } catch (_) {
          // This can very infrequently fail due to CDN or caching issues,
          // or if the upstream file has an incorrect link.
          _log.info('Failed to retrieve release notes for v$releaseToCheck, '
              'despite indication it is live at $releaseNotePath.');
          // If we couldn't retrieve this page, keep going to
          // try with earlier patch versions.
          continue;
        }

        // Update the base-url-relative links in the file to absolute links.
        markdown.value = _convertBaseUrlRelativeLinks(
          releaseNotesMarkdown,
          _flutterDocsSite,
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

  /// Convert all site-base-url relative links in [markdownContent]
  /// to absolute links from the specified [baseUrl].
  ///
  /// For example, if `baseUrl` is `https://docs.flutter.dev`,
  /// the path `/tools/devtools` would be converted
  /// to `https://docs.flutter.dev/tools/devtools`.
  String _convertBaseUrlRelativeLinks(String markdownContent, Uri baseUrl) =>
      markdownContent.replaceAllMapped(
        _baseUrlRelativeMarkdownLinkPattern,
        (m) => '${m[1]}${baseUrl.toString()}${m[2]}',
      );

  /// Retrieve and parse the release note index from the
  /// Flutter website at [_flutterDocsSite]/[_releaseNotesPath].
  ///
  /// Calls [_emptyAndClose] and returns `null` if
  /// the retrieval or parsing fails.
  @visibleForTesting
  Future<Map<String, String>?> retrieveReleasesFromIndex() async {
    final Map<String, Object?> releaseIndex;
    try {
      final releaseIndexString = await http.read(releaseIndexUrl);
      releaseIndex = jsonDecode(releaseIndexString) as Map<String, Object?>;
    } catch (e) {
      // This can occur if the file can't be retrieved or if its not a JSON map.
      _emptyAndClose(e.toString());
      return null;
    }

    final releases = releaseIndex['releases'];
    if (releases is! Map<String, Object?>) {
      _emptyAndClose(
        'The DevTools release index file was incorrectly formatted.',
      );
      return null;
    }
    return releases.cast<String, String>();
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

// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;

import '../../../devtools.dart' as devtools;
import '../../config_specific/launch_url/launch_url.dart';
import '../../config_specific/logger/logger.dart' as logger;
import '../../config_specific/server/server.dart' as server;
import '../../primitives/auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../theme.dart';
import '../utils.dart';
import '../version.dart';

const debugTestReleaseNotes = false;

class ReleaseNotesViewer extends StatefulWidget {
  const ReleaseNotesViewer({
    Key? key,
    required this.releaseNotesController,
    required this.child,
  }) : super(key: key);

  final ReleaseNotesController releaseNotesController;

  final Widget? child;

  @override
  _ReleaseNotesViewerState createState() => _ReleaseNotesViewerState();
}

class _ReleaseNotesViewerState extends State<ReleaseNotesViewer>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  static const maxViewerWidth = 600.0;

  /// Animation controller for animating the opening and closing of the viewer.
  late AnimationController visibilityController;

  /// A curved animation that matches [visibilityController].
  late Animation<double> visibilityAnimation;

  String? markdownData;

  late bool isVisible;

  @override
  void initState() {
    super.initState();
    isVisible = widget.releaseNotesController.releaseNotesVisible.value;
    markdownData = widget.releaseNotesController.releaseNotesMarkdown.value;

    visibilityController = longAnimationController(this);
    visibilityAnimation =
        Tween<double>(begin: 1.0, end: 0).animate(visibilityController);

    addAutoDisposeListener(widget.releaseNotesController.releaseNotesVisible,
        () {
      setState(() {
        isVisible = widget.releaseNotesController.releaseNotesVisible.value;
        if (isVisible) {
          visibilityController.forward();
        } else {
          visibilityController.reverse();
        }
      });
    });

    markdownData = widget.releaseNotesController.releaseNotesMarkdown.value;
    addAutoDisposeListener(widget.releaseNotesController.releaseNotesMarkdown,
        () {
      setState(() {
        markdownData = widget.releaseNotesController.releaseNotesMarkdown.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return Material(
      child: Stack(
        children: [
          if (child != null) child,
          LayoutBuilder(
            builder: (context, constraints) {
              final widthForSmallScreen =
                  constraints.maxWidth - 2 * densePadding;
              final width = min(
                _ReleaseNotesViewerState.maxViewerWidth,
                widthForSmallScreen,
              );

              return Stack(
                children: [
                  ReleaseNotes(
                    releaseNotesController: widget.releaseNotesController,
                    visibilityAnimation: visibilityAnimation,
                    markdownData: markdownData,
                    width: width,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class ReleaseNotes extends AnimatedWidget {
  const ReleaseNotes({
    Key? key,
    required this.releaseNotesController,
    required Animation<double> visibilityAnimation,
    required this.markdownData,
    required this.width,
  }) : super(key: key, listenable: visibilityAnimation);

  final ReleaseNotesController releaseNotesController;

  final String? markdownData;

  final double width;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final theme = Theme.of(context);
    final displacement = width * animation.value;
    final right = densePadding - displacement;
    return Positioned(
      top: densePadding,
      bottom: densePadding,
      right: right,
      width: width,
      child: Card(
        elevation: defaultElevation,
        color: theme.scaffoldBackgroundColor,
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          side: BorderSide(
            color: theme.focusColor,
          ),
        ),
        child: Column(
          children: [
            AreaPaneHeader(
              title: const Expanded(
                child: Text(
                  'What\'s new in DevTools?',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              needsTopBorder: false,
              rightActions: [
                IconButton(
                  padding: const EdgeInsets.all(0.0),
                  onPressed: () =>
                      releaseNotesController.toggleReleaseNotesVisible(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            markdownData == null
                ? const Text('Stay tuned for updates.')
                : Expanded(
                    child: Markdown(
                      data: markdownData!,
                      onTapLink: (_, href, __) => launchUrl(href!, context),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class ReleaseNotesController {
  ReleaseNotesController() {
    _init();
  }

  static const _unsupportedPathSyntax = '{{site.url}}';

  String get _flutterDocsSite => debugTestReleaseNotes
      ? 'https://flutter-website-dt-staging.web.app'
      : 'https://docs.flutter.dev';

  ValueListenable<String?> get releaseNotesMarkdown => _releaseNotesMarkdown;

  final _releaseNotesMarkdown = ValueNotifier<String?>(null);

  ValueListenable<bool> get releaseNotesVisible => _releaseNotesVisible;

  final _releaseNotesVisible = ValueNotifier<bool>(false);

  void _init() {
    if (server.isDevToolsServerAvailable && !isEmbedded()) {
      _maybeFetchReleaseNotes();
    }
  }

  void _maybeFetchReleaseNotes() async {
    final lastReleaseNotesShownVersion =
        await server.getLastShownReleaseNotesVersion();
    SemanticVersion previousVersion;
    if (debugTestReleaseNotes || lastReleaseNotesShownVersion.isEmpty) {
      previousVersion = SemanticVersion();
    } else {
      previousVersion = SemanticVersion.parse(lastReleaseNotesShownVersion);
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
        _releaseNotesMarkdown.value = null;
        toggleReleaseNotesVisible(false);
        logger.log(
          'Warning: could not find release notes for DevTools version '
          '$parsedCurrentVersionStr. $e',
          logger.LogLevel.warning,
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

        _releaseNotesMarkdown.value = releaseNotesMarkdown;
        toggleReleaseNotesVisible(true);
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

  void toggleReleaseNotesVisible(bool visible) {
    _releaseNotesVisible.value = visible;
  }

  String _releaseNotesUrl(String currentVersion) {
    return '$_flutterDocsSite/development/tools/devtools/release-notes/'
        'release-notes-$currentVersion-src.md';
  }
}

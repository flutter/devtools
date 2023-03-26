// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;

import '../../devtools.dart' as devtools;
import 'common_widgets.dart';
import 'config_specific/launch_url/launch_url.dart';
import 'config_specific/logger/logger.dart' as logger;
import 'config_specific/server/server.dart' as server;
import 'primitives/auto_dispose.dart';
import 'theme.dart';

const debugTestReleaseNotes = false;

const releaseNotesTitle = 'What\'s new in DevTools?';
const releaseNotesTextWhenEmpty = 'Stay tuned for updates.';

const releaseNotesKey = Key('release_notes');
const diffSnapshotsHelpPanelKey = Key('diff_snapshots_help_panel');

class SidePanelViewer extends StatefulWidget {
  const SidePanelViewer({
    Key? key,
    required this.controller,
    this.title,
    this.textIfMarkdownDataEmpty,
    this.child,
  }) : super(key: key);

  final SidePanelController controller;
  final String? title;
  final String? textIfMarkdownDataEmpty;
  final Widget? child;

  @override
  SidePanelViewerState createState() => SidePanelViewerState();
}

class SidePanelViewerState extends State<SidePanelViewer>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  static const maxViewerWidth = 600.0;

  /// Animation controller for animating the opening and closing of the viewer.
  late AnimationController visibilityController;

  /// A curved animation that matches [visibilityController].
  late Animation<double> visibilityAnimation;

  String? markdownData;

  late bool isVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    isVisible = widget.controller.isVisible.value;
    markdownData = widget.controller.markdown.value;

    visibilityController = longAnimationController(this);
    visibilityAnimation =
        Tween<double>(begin: 1.0, end: 0).animate(visibilityController);

    addAutoDisposeListener(widget.controller.isVisible, () {
      setState(() {
        isVisible = widget.controller.isVisible.value;
        if (isVisible) {
          visibilityController.forward();
        } else {
          visibilityController.reverse();
        }
      });
    });

    markdownData = widget.controller.markdown.value;
    addAutoDisposeListener(widget.controller.markdown, () {
      setState(() {
        markdownData = widget.controller.markdown.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return Material(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widthForSmallScreen = constraints.maxWidth - 2 * densePadding;
          final width = min(
            SidePanelViewerState.maxViewerWidth,
            widthForSmallScreen,
          );
          return Stack(
            children: [
              if (child != null) child,
              SidePanel(
                sidePanelController: widget.controller,
                visibilityAnimation: visibilityAnimation,
                title: widget.title,
                markdownData: markdownData,
                textIfMarkdownDataEmpty: widget.textIfMarkdownDataEmpty,
                width: width,
              ),
            ],
          );
        },
      ),
    );
  }
}

class SidePanel extends AnimatedWidget {
  const SidePanel({
    Key? key,
    required this.sidePanelController,
    required Animation<double> visibilityAnimation,
    this.title,
    this.markdownData,
    this.textIfMarkdownDataEmpty,
    required this.width,
  }) : super(key: key, listenable: visibilityAnimation);

  final SidePanelController sidePanelController;

  final String? title;
  final String? markdownData;
  final String? textIfMarkdownDataEmpty;
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
              title: Text(title ?? ''),
              includeTopBorder: false,
              actions: [
                IconButton(
                  padding: const EdgeInsets.all(0.0),
                  onPressed: () => sidePanelController.toggleVisibility(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            (markdownData == null || markdownData!.isEmpty)
                ? Text(textIfMarkdownDataEmpty ?? '')
                : Expanded(
                    child: Markdown(
                      data: markdownData!,
                      onTapLink: (text, url, title) async =>
                          await launchUrl(url!),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

abstract class SidePanelController {
  ValueListenable<String?> get markdown => _markdown;

  final _markdown = ValueNotifier<String?>(null);

  ValueListenable<bool> get isVisible => _isVisible;

  final _isVisible = ValueNotifier<bool>(false);

  void toggleVisibility(bool visible) {
    _isVisible.value = visible;
  }
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
        _markdown.value = null;
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

        _markdown.value = releaseNotesMarkdown;
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
    _isVisible.value = visible;
  }

  String _releaseNotesUrl(String currentVersion) {
    return '$_flutterDocsSite/development/tools/devtools/release-notes/'
        'release-notes-$currentVersion-src.md';
  }
}

class SidePanelControllerMarkdownString extends SidePanelController {
  SidePanelControllerMarkdownString(
    String markdownText,
  ) {
    _markdown.value = markdownText;
  }

  set markdownText(String markdownText) {
    _markdown.value = markdownText;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;

import '../devtools.dart' as devtools;
import '../devtools_app.dart';
import 'config_specific/launch_url/launch_url.dart';
import 'config_specific/logger/logger.dart' as logger;
import 'config_specific/server/server.dart' as server;

class ReleaseNotesViewer extends StatefulWidget {
  const ReleaseNotesViewer({
    Key key,
    @required this.releaseNotesController,
    @required this.child,
  }) : super(key: key);

  final ReleaseNotesController releaseNotesController;

  final Widget child;

  @override
  _ReleaseNotesViewerState createState() => _ReleaseNotesViewerState();
}

class _ReleaseNotesViewerState extends State<ReleaseNotesViewer>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  static const viewerWidth = 600.0;

  /// Animation controller for animating the opening and closing of the viewer.
  AnimationController visibilityController;

  /// A curved animation that matches [visibilityController].
  Animation<double> visibilityAnimation;

  String markdownData;

  bool isVisible;

  @override
  void initState() {
    super.initState();
    isVisible = widget.releaseNotesController.releaseNotesVisible.value;
    markdownData = widget.releaseNotesController.releaseNotesMarkdown.value;

    visibilityController = longAnimationController(this);
    // Add [densePadding] to the end to account for the space between the
    // release notes viewer and the right edge of DevTools.
    visibilityAnimation =
        Tween<double>(begin: 0, end: viewerWidth + densePadding)
            .animate(visibilityController);

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
    return Material(
      child: Stack(
        children: [
          widget.child,
          ReleaseNotes(
            releaseNotesController: widget.releaseNotesController,
            visibilityAnimation: visibilityAnimation,
            markdownData: markdownData,
          ),
        ],
      ),
    );
  }
}

class ReleaseNotes extends AnimatedWidget {
  const ReleaseNotes({
    Key key,
    @required this.releaseNotesController,
    @required Animation<double> visibilityAnimation,
    @required this.markdownData,
  }) : super(key: key, listenable: visibilityAnimation);

  final ReleaseNotesController releaseNotesController;

  final String markdownData;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final theme = Theme.of(context);
    return Positioned(
      top: densePadding,
      bottom: densePadding,
      right: densePadding -
          (_ReleaseNotesViewerState.viewerWidth - animation.value),
      width: _ReleaseNotesViewerState.viewerWidth,
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
              title: const Text('What\'s new in DevTools?'),
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
                      data: markdownData,
                      onTapLink: (_, href, __) => launchUrl(href, context),
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

  ValueListenable<String> get releaseNotesMarkdown => _releaseNotesMarkdown;

  final _releaseNotesMarkdown = ValueNotifier<String>(null);

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
    if (lastReleaseNotesShownVersion.isEmpty) {
      previousVersion = SemanticVersion();
    } else {
      previousVersion = SemanticVersion.parse(lastReleaseNotesShownVersion);
    }
    const devtoolsVersion = devtools.version;
    final currentVersion = SemanticVersion.parse(devtoolsVersion);
    if (currentVersion > previousVersion) {
      try {
        String releaseNotesMarkdown =
            await http.read(Uri.parse(_releaseNotesUrl(devtoolsVersion)));
        // This is a workaround so that the images in release notes will appear.
        // The {{site.url}} syntax is best practices for the flutter website
        // repo, where these release notes are hosted, so we are performing this
        // workaround on our end to ensure the images render properly.
        releaseNotesMarkdown = releaseNotesMarkdown.replaceAll(
          '{{site.url}}',
          'https://docs.flutter.dev',
        );

        _releaseNotesMarkdown.value = releaseNotesMarkdown;
        toggleReleaseNotesVisible(true);
        unawaited(server.setLastShownReleaseNotesVersion(devtoolsVersion));
      } catch (e) {
        // Fail gracefully if we cannot find release notes for the current
        // version of DevTools.
        _releaseNotesMarkdown.value = null;
        toggleReleaseNotesVisible(false);
        logger.log(
          'Warning: could not find release notes for DevTools version '
          '$currentVersion. $e',
          logger.LogLevel.warning,
        );
      }
    }
  }

  void toggleReleaseNotesVisible(bool visible) {
    _releaseNotesVisible.value = visible;
  }

  String _releaseNotesUrl(String currentVersion) {
    return 'https://docs.flutter.dev/development/tools/devtools/release-notes/release-notes-$currentVersion-src.md';
  }
}

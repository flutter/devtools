// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/utils.dart';
import '../../shared/utils/utils.dart';
import 'scaffold.dart';

/// The status line widget displayed at the bottom of DevTools.
///
/// This displays information global to the application, as well as gives pages
/// a mechanism to display page-specific information.
class StatusLine extends StatelessWidget {
  const StatusLine({
    super.key,
    required this.currentScreen,
    required this.isEmbedded,
    required this.isConnected,
  }) : highlightForConnection = isConnected && !isEmbedded;

  final Screen currentScreen;

  final bool isEmbedded;

  final bool isConnected;

  /// Whether to highlight the footer when DevTools is connected to an app.
  final bool highlightForConnection;

  /// The padding around the footer in the DevTools UI.
  EdgeInsets get padding => const EdgeInsets.symmetric(
    horizontal: defaultSpacing,
    vertical: densePadding,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = highlightForConnection
        ? theme.colorScheme.primary
        : null;
    final foregroundColor = highlightForConnection
        ? theme.colorScheme.onPrimary
        : null;
    final height = statusLineHeight + padding.top + padding.bottom;
    return ValueListenableBuilder<bool>(
      valueListenable: currentScreen.showIsolateSelector,
      builder: (context, showIsolateSelector, _) {
        showIsolateSelector = showIsolateSelector && isConnected;
        // Keep every footer item on a single line. Items that do not fit are
        // truncated rather than overflowing the status line.
        return DefaultTextStyle.merge(
          style: TextStyle(color: foregroundColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                top: Divider.createBorderSide(context, width: 1.0),
              ),
            ),
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            height: height,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _getStatusItems(context, showIsolateSelector),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _getStatusItems(BuildContext context, bool showIsolateSelector) {
    final theme = Theme.of(context);
    final foregroundColor = highlightForConnection
        ? theme.colorScheme.onPrimary
        : null;
    final screenWidth = ScreenSize(context).width;
    // TODO(https://github.com/flutter/devtools/issues/8913): this builds the
    // wrong status items for offline mode.
    final pageStatus = currentScreen.buildStatus(context);
    final widerThanXxs = screenWidth > MediaSize.xxs;
    final screenMetaData = ScreenMetaData.lookup(currentScreen.screenId);
    final showVideoTutorial =
        screenMetaData?.tutorialVideoTimestamp != null ||
        screenMetaData?.tutorialVideoUrl != null;
    // Secondary items (the tutorial link and, when embedded, the DevTools
    // actions) are shown inline only on wide screens. Below [MediaSize.s] they
    // move into one overflow menu, so they stay reachable and the device name
    // and page status are not squeezed.
    final showSecondaryItemsInline = screenWidth > MediaSize.s;
    final showTutorialInline = showVideoTutorial && showSecondaryItemsInline;
    final embeddedActions = isEmbedded
        ? DevToolsScaffold.defaultActions(
            color: foregroundColor,
            currentScreen: currentScreen,
          )
        : const <ScaffoldAction>[];
    final overflowTutorial = showVideoTutorial && !showTutorialInline
        ? screenMetaData
        : null;
    final overflowActions = showSecondaryItemsInline
        ? const <ScaffoldAction>[]
        : embeddedActions;
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DocumentationLink(
            screen: currentScreen,
            screenWidth: screenWidth,
            highlightForConnection: highlightForConnection,
          ),
          if (showTutorialInline) ...[
            BulletSpacer(color: foregroundColor),
            VideoTutorialLink(
              screenMetaData: screenMetaData!,
              highlightForConnection: highlightForConnection,
            ),
          ],
        ],
      ),
      BulletSpacer(color: foregroundColor),
      if (widerThanXxs && showIsolateSelector) ...[
        IsolateSelector(foregroundColor: foregroundColor),
        BulletSpacer(color: foregroundColor),
      ],
      if (screenWidth > MediaSize.xs && pageStatus != null) ...[
        // The page status needs to be flexible so that the status line can
        // shrink to fit narrow screens without overflowing.
        Expanded(child: pageStatus),
        BulletSpacer(color: foregroundColor),
      ],
      // The connection status needs to be flexible so that the status line
      // can shrink to fit narrow screens without overflowing.
      Flexible(child: buildConnectionStatus(context, screenWidth)),
      if (showSecondaryItemsInline && embeddedActions.isNotEmpty) ...[
        BulletSpacer(color: foregroundColor),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: embeddedActions,
        ),
      ],
      if (overflowTutorial != null || overflowActions.isNotEmpty) ...[
        BulletSpacer(color: foregroundColor),
        _StatusLineOverflowMenu(
          tutorial: overflowTutorial,
          actions: overflowActions,
          color: foregroundColor,
        ),
      ],
    ];
  }

  Widget buildConnectionStatus(BuildContext context, MediaSize screenWidth) {
    final theme = Theme.of(context);
    const noConnectionMsg = 'No client connection';
    return ValueListenableBuilder<ConnectedState>(
      valueListenable: serviceConnection.serviceManager.connectedState,
      builder: (context, connectedState, child) {
        if (connectedState.connected) {
          final app = serviceConnection.serviceManager.connectedApp!;

          String description;
          if (!app.isRunningOnDartVM!) {
            description = 'web app';
          } else {
            final vm = serviceConnection.serviceManager.vm!;
            description = vm.deviceDisplay;
          }

          final color = highlightForConnection
              ? theme.colorScheme.onPrimary
              : theme.regularTextStyle.color;

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ValueListenableBuilder(
                valueListenable: serviceConnection.serviceManager.deviceBusy,
                builder: (context, bool isBusy, _) {
                  return SizedBox(
                    width: smallProgressSize,
                    height: smallProgressSize,
                    child: isBusy
                        ? SmallCircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color?>(color),
                          )
                        : const SizedBox(),
                  );
                },
              ),
              const SizedBox(width: denseSpacing),
              Flexible(
                child: DevToolsTooltip(
                  message: 'Connected device',
                  child: Text(
                    description,
                    style: highlightForConnection
                        ? theme.regularTextStyle.copyWith(
                            color: theme.colorScheme.onPrimary,
                          )
                        : theme.regularTextStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
        } else {
          return child!;
        }
      },
      child: screenWidth <= MediaSize.xs
          ? const DevToolsTooltip(
              message: noConnectionMsg,
              child: Icon(Icons.warning_amber_rounded, size: actionsIconSize),
            )
          : Text(noConnectionMsg, style: theme.regularTextStyle),
    );
  }
}

/// A widget that links to DevTools documentation on docs.flutter.dev for the
/// given [screen].
class DocumentationLink extends StatelessWidget {
  const DocumentationLink({
    super.key,
    required this.screen,
    required this.screenWidth,
    required this.highlightForConnection,
  });

  final Screen screen;

  final MediaSize screenWidth;

  final bool highlightForConnection;

  @override
  Widget build(BuildContext context) {
    final color = highlightForConnection
        ? Theme.of(context).colorScheme.onPrimary
        : null;
    final docPageId = screen.docPageId ?? '';
    return LinkIconLabel(
      icon: Icons.library_books_outlined,
      link: GaLink(
        display: screenWidth <= MediaSize.xs ? 'Docs' : 'Read docs',
        url:
            screen.docsUrl ??
            'https://docs.flutter.dev/tools/devtools/$docPageId',
        gaScreenName: screen.screenId,
        gaSelectedItemDescription: gac.documentationLink,
      ),
      color: color,
    );
  }
}

/// A widget that links to the "Dive in to DevTools" YouTube video at the
/// chapter for the given [screenMetaData].
class VideoTutorialLink extends StatelessWidget {
  VideoTutorialLink({
    super.key,
    required this.screenMetaData,
    required this.highlightForConnection,
  }) : assert(
         screenMetaData.tutorialVideoTimestamp != null ||
             screenMetaData.tutorialVideoUrl != null,
       );

  final ScreenMetaData screenMetaData;

  final bool highlightForConnection;

  static const _devToolsYouTubeVideoUrl = 'https://youtu.be/_EYk-E29edo';

  static GaLink _linkFor(ScreenMetaData screenMetaData) {
    return GaLink(
      display: 'Watch tutorial',
      url:
          screenMetaData.tutorialVideoUrl ??
          '$_devToolsYouTubeVideoUrl${screenMetaData.tutorialVideoTimestamp}',
      gaScreenName: screenMetaData.id,
      gaSelectedItemDescription:
          '${gac.videoTutorialLink}-${screenMetaData.id}',
    );
  }

  /// Opens the tutorial video for [screenMetaData] and records the same
  /// analytics event as this link, for use from the overflow menu.
  static void open(ScreenMetaData screenMetaData) {
    final link = _linkFor(screenMetaData);
    unawaited(launchUrlWithErrorHandling(link.url));
    ga.select(link.gaScreenName!, link.gaSelectedItemDescription!);
  }

  @override
  Widget build(BuildContext context) {
    final color = highlightForConnection
        ? Theme.of(context).colorScheme.onPrimary
        : null;
    return LinkIconLabel(
      icon: Icons.ondemand_video_rounded,
      link: _linkFor(screenMetaData),
      color: color,
    );
  }
}

/// The footer items that do not fit at the current width: the video tutorial
/// link and, for embedded DevTools, the DevTools actions (Settings, Feedback,
/// About, and extension settings), in one menu.
///
/// Each item runs the same behavior as its inline counterpart.
class _StatusLineOverflowMenu extends StatelessWidget {
  const _StatusLineOverflowMenu({
    required this.tutorial,
    required this.actions,
    required this.color,
  });

  /// The metadata of the screen whose tutorial should be offered, if any.
  final ScreenMetaData? tutorial;

  final List<ScaffoldAction> actions;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tutorial = this.tutorial;
    return PopupMenuButton<VoidCallback>(
      tooltip: 'More actions',
      padding: EdgeInsets.zero,
      onSelected: (onSelected) => onSelected(),
      itemBuilder: (_) => [
        if (tutorial != null)
          PopupMenuItem(
            value: () => VideoTutorialLink.open(tutorial),
            child: const Text('Watch tutorial'),
          ),
        for (final action in actions)
          PopupMenuItem(
            value: () => action.onPressed(context),
            child: Text(action.tooltip),
          ),
      ],
      child: SizedBox(
        width: actionWidgetSize,
        child: Center(
          child: Icon(Icons.more_horiz, size: actionsIconSize, color: color),
        ),
      ),
    );
  }
}

class IsolateSelector extends StatelessWidget {
  const IsolateSelector({super.key, required this.foregroundColor});

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final isolateManager = serviceConnection.serviceManager.isolateManager;
    return MultiValueListenableBuilder(
      listenables: [isolateManager.isolates, isolateManager.selectedIsolate],
      builder: (context, values, _) {
        final isolates = values.first as List<IsolateRef>;
        final selectedIsolateRef = values.second as IsolateRef?;
        return PopupMenuButton<IsolateRef?>(
          tooltip: 'Selected Isolate',
          initialValue: selectedIsolateRef,
          onSelected: isolateManager.selectIsolate,
          itemBuilder: (BuildContext context) => isolates.map((ref) {
            return PopupMenuItem<IsolateRef>(
              value: ref,
              child: _IsolateOption(
                ref,
                // This is always rendered against the background color
                // for the pop up menu, which is the `surface` color.
                color: Theme.of(context).colorScheme.onSurface,
              ),
            );
          }).toList(),
          child: _IsolateOption(
            isolateManager.selectedIsolate.value,
            color: foregroundColor,
          ),
        );
      },
    );
  }
}

class _IsolateOption extends StatelessWidget {
  const _IsolateOption(this.ref, {required this.color});

  final IsolateRef? ref;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ref?.isSystemIsolate ?? false
              ? Icons.settings_applications
              : Icons.call_split,
          color: color,
        ),
        const SizedBox(width: denseSpacing),
        Text(
          ref == null ? 'isolate' : _isolateName(ref!),
          style: Theme.of(context).regularTextStyle.copyWith(color: color),
        ),
      ],
    );
  }

  String _isolateName(IsolateRef ref) {
    final name = ref.name;
    return '$name #${serviceConnection.serviceManager.isolateManager.isolateIndex(ref)}';
  }
}

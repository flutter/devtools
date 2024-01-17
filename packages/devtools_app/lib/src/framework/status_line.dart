// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import '../shared/primitives/utils.dart';
import '../shared/screen.dart';
import '../shared/ui/utils.dart';
import '../shared/utils.dart';
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
  });

  final Screen currentScreen;
  final bool isEmbedded;
  final bool isConnected;

  static const deviceInfoTooltip = 'Device Info';

  /// The padding around the footer in the DevTools UI.
  EdgeInsets get padding => const EdgeInsets.fromLTRB(
        defaultSpacing,
        densePadding,
        defaultSpacing,
        densePadding,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isConnected ? theme.colorScheme.onPrimary : null;
    final height = statusLineHeight + padding.top + padding.bottom;
    return ValueListenableBuilder<bool>(
      valueListenable: currentScreen.showIsolateSelector,
      builder: (context, showIsolateSelector, _) {
        return DefaultTextStyle.merge(
          style: TextStyle(color: color),
          child: Container(
            decoration: BoxDecoration(
              color: isConnected ? theme.colorScheme.primary : null,
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
    final color = isConnected ? theme.colorScheme.onPrimary : null;
    final screenWidth = ScreenSize(context).width;
    final Widget? pageStatus = currentScreen.buildStatus(context);
    final widerThanXxs = screenWidth > MediaSize.xxs;
    final screenMetaData = ScreenMetaData.lookup(currentScreen.screenId);
    final showVideoTutorial = screenMetaData?.tutorialVideoTimestamp != null;
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DocumentationLink(
            screen: currentScreen,
            screenWidth: screenWidth,
            isConnected: isConnected,
          ),
          if (showVideoTutorial) ...[
            BulletSpacer(color: color),
            VideoTutorialLink(
              screenMetaData: screenMetaData!,
              screenWidth: screenWidth,
              isConnected: isConnected,
            ),
          ],
        ],
      ),
      BulletSpacer(color: color),
      if (widerThanXxs && showIsolateSelector) ...[
        const IsolateSelector(),
        BulletSpacer(color: color),
      ],
      if (screenWidth > MediaSize.xs && pageStatus != null) ...[
        pageStatus,
        BulletSpacer(color: color),
      ],
      buildConnectionStatus(context, screenWidth),
      if (widerThanXxs && isEmbedded) ...[
        BulletSpacer(color: color),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: DevToolsScaffold.defaultActions(color: color),
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

          final color = isConnected
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
              DevToolsTooltip(
                message: 'Connected device',
                child: Text(
                  description,
                  style: isConnected
                      ? theme.regularTextStyle
                          .copyWith(color: theme.colorScheme.onPrimary)
                      : theme.regularTextStyle,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          );
        } else {
          return child!;
        }
      },
      child: screenWidth <= MediaSize.xxs
          ? DevToolsTooltip(
              message: noConnectionMsg,
              child: Icon(
                Icons.warning_amber_rounded,
                size: actionsIconSize,
              ),
            )
          : Text(
              noConnectionMsg,
              style: theme.regularTextStyle,
            ),
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
    required this.isConnected,
  });

  final Screen screen;

  final MediaSize screenWidth;

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? Theme.of(context).colorScheme.onPrimary : null;
    final docPageId = screen.docPageId ?? '';
    return LinkIconLabel(
      icon: Icons.library_books_outlined,
      link: Link(
        display: screenWidth <= MediaSize.xs ? 'Docs' : 'Read docs',
        url: 'https://docs.flutter.dev/tools/devtools/$docPageId',
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
  const VideoTutorialLink({
    super.key,
    required this.screenMetaData,
    required this.screenWidth,
    required this.isConnected,
  });

  final ScreenMetaData screenMetaData;

  final MediaSize screenWidth;

  final bool isConnected;

  static const _devToolsYouTubeVideoUrl = 'https://youtu.be/_EYk-E29edo';

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? Theme.of(context).colorScheme.onPrimary : null;
    return LinkIconLabel(
      icon: Icons.ondemand_video_rounded,
      link: Link(
        display: screenWidth <= MediaSize.xs ? 'Tutorial' : 'Watch tutorial',
        url:
            '$_devToolsYouTubeVideoUrl${screenMetaData.tutorialVideoTimestamp}',
        gaScreenName: screenMetaData.id,
        gaSelectedItemDescription:
            '${gac.videoTutorialLink}-${screenMetaData.id}',
      ),
      color: color,
    );
  }
}

class IsolateSelector extends StatelessWidget {
  const IsolateSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final IsolateManager isolateManager =
        serviceConnection.serviceManager.isolateManager;
    return MultiValueListenableBuilder(
      listenables: [
        isolateManager.isolates,
        isolateManager.selectedIsolate,
      ],
      builder: (context, values, _) {
        final theme = Theme.of(context);
        final isolates = values.first as List<IsolateRef>;
        final selectedIsolateRef = values.second as IsolateRef?;
        return PopupMenuButton<IsolateRef?>(
          tooltip: 'Selected Isolate',
          initialValue: selectedIsolateRef,
          onSelected: isolateManager.selectIsolate,
          itemBuilder: (BuildContext context) => isolates.map(
            (ref) {
              return PopupMenuItem<IsolateRef>(
                value: ref,
                child: IsolateOption(
                  ref,
                  color: theme.colorScheme.onSurface,
                ),
              );
            },
          ).toList(),
          child: IsolateOption(
            isolateManager.selectedIsolate.value,
            color: theme.colorScheme.onPrimary,
          ),
        );
      },
    );
  }
}

class IsolateOption extends StatelessWidget {
  const IsolateOption(
    this.ref, {
    required this.color,
    super.key,
  });

  final IsolateRef? ref;

  final Color color;

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

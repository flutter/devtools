// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools;
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
    final height = statusLineHeight + padding.top + padding.bottom;
    return ValueListenableBuilder<bool>(
      valueListenable: currentScreen.showIsolateSelector,
      builder: (context, showIsolateSelector, _) {
        return Container(
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
    return [
      buildHelpUrlStatus(context, currentScreen, screenWidth),
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
          children: DevToolsScaffold.defaultActions(
            color: color,
            isEmbedded: isEmbedded,
          ),
        ),
      ],
    ];
  }

  Widget buildHelpUrlStatus(
    BuildContext context,
    Screen currentScreen,
    MediaSize screenWidth,
  ) {
    final theme = Theme.of(context);
    final style = theme.linkTextStyle;
    final String? docPageId = currentScreen.docPageId;
    if (docPageId != null) {
      return RichText(
        text: LinkTextSpan(
          link: Link(
            display: screenWidth <= MediaSize.xs
                ? docPageId
                : 'flutter.dev/devtools/$docPageId',
            url: 'https://flutter.dev/devtools/$docPageId',
            gaScreenName: currentScreen.screenId,
            gaSelectedItemDescription: gac.documentationLink,
          ),
          style: isConnected
              ? style.copyWith(color: theme.colorScheme.onPrimary)
              : style,
          context: context,
        ),
      );
    } else {
      // Use a placeholder for pages with no explicit documentation.
      return Flexible(
        child: Text(
          '${screenWidth <= MediaSize.xs ? '' : 'DevTools '}${devtools.version}',
          overflow: TextOverflow.ellipsis,
          style: isConnected
              ? theme.regularTextStyle
                  .copyWith(color: theme.colorScheme.onPrimary)
              : theme.regularTextStyle,
        ),
      );
    }
  }

  Widget buildConnectionStatus(BuildContext context, MediaSize screenWidth) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
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
              : textTheme.bodyMedium!.color;

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
                      ? textTheme.bodyMedium!
                          .copyWith(color: theme.colorScheme.onPrimary)
                      : textTheme.bodyMedium,
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
              style: textTheme.bodyMedium,
            ),
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
    final textTheme = Theme.of(context).textTheme;
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
          style: textTheme.bodyMedium!.copyWith(color: color),
        ),
      ],
    );
  }

  String _isolateName(IsolateRef ref) {
    final name = ref.name;
    return '$name #${serviceConnection.serviceManager.isolateManager.isolateIndex(ref)}';
  }
}

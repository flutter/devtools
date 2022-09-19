// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools;
import '../analytics/constants.dart' as analytics_constants;
import '../service/isolate_manager.dart';
import '../service/service_manager.dart';
import '../shared/common_widgets.dart';
import '../shared/device_dialog.dart';
import '../shared/globals.dart';
import '../shared/screen.dart';
import '../shared/theme.dart';
import '../shared/utils.dart';
import '../ui/utils.dart';
import 'about_dialog.dart';
import 'report_feedback_button.dart';

/// The status line widget displayed at the bottom of DevTools.
///
/// This displays information global to the application, as well as gives pages
/// a mechanism to display page-specific information.
class StatusLine extends StatelessWidget {
  const StatusLine({required this.currentScreen, required this.isEmbedded});

  final Screen currentScreen;
  final bool isEmbedded;

  /// The padding around the footer in the DevTools UI.
  EdgeInsets get padding => const EdgeInsets.fromLTRB(
        defaultSpacing,
        defaultSpacing,
        defaultSpacing,
        denseSpacing,
      );

  @override
  Widget build(BuildContext context) {
    final height = statusLineHeight + padding.top + padding.bottom;
    return ValueListenableBuilder<bool>(
      valueListenable: currentScreen.showIsolateSelector,
      builder: (context, showIsolateSelector, _) {
        return Container(
          decoration: BoxDecoration(
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
    final screenWidth = ScreenSize(context).width;
    final Widget? pageStatus = currentScreen.buildStatus(context);
    final widerThanXxs = screenWidth > MediaSize.xxs;
    return [
      buildHelpUrlStatus(context, currentScreen, screenWidth),
      const BulletSpacer(),
      if (widerThanXxs && showIsolateSelector) ...[
        const IsolateSelector(),
        const BulletSpacer(),
      ],
      if (screenWidth > MediaSize.xs && pageStatus != null) ...[
        pageStatus,
        const BulletSpacer(),
      ],
      buildConnectionStatus(context, screenWidth),
      if (widerThanXxs && isEmbedded) ...[
        const BulletSpacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ReportFeedbackButton(),
            OpenAboutAction(),
          ],
        ),
      ]
    ];
  }

  Widget buildHelpUrlStatus(
    BuildContext context,
    Screen currentScreen,
    MediaSize screenWidth,
  ) {
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
            gaSelectedItemDescription: analytics_constants.documentationLink,
          ),
          context: context,
        ),
      );
    } else {
      // Use a placeholder for pages with no explicit documentation.
      return Flexible(
        child: Text(
          '${screenWidth <= MediaSize.xs ? '' : 'DevTools '}${devtools.version}',
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
  }

  Widget buildConnectionStatus(BuildContext context, MediaSize screenWidth) {
    final textTheme = Theme.of(context).textTheme;
    const noConnectionMsg = 'No client connection';
    return ValueListenableBuilder<ConnectedState>(
      valueListenable: serviceManager.connectedState,
      builder: (context, connectedState, child) {
        if (connectedState.connected) {
          final app = serviceManager.connectedApp!;

          String description;
          if (!app.isRunningOnDartVM!) {
            description = 'web app';
          } else {
            final vm = serviceManager.vm!;
            description = vm.deviceDisplay;
          }

          final color = textTheme.bodyMedium!.color;

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ValueListenableBuilder(
                valueListenable: serviceManager.deviceBusy,
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
                message: 'Device Info',
                child: InkWell(
                  onTap: () async {
                    unawaited(
                      showDialog(
                        context: context,
                        builder: (context) => DeviceDialog(
                          connectedApp: app,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: actionsIconSize,
                      ),
                      if (screenWidth > MediaSize.xxs) ...[
                        const SizedBox(width: denseSpacing),
                        Text(
                          description,
                          style: textTheme.bodyMedium,
                          overflow: TextOverflow.clip,
                        ),
                      ]
                    ],
                  ),
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
    final IsolateManager isolateManager = serviceManager.isolateManager;
    return DualValueListenableBuilder<List<IsolateRef?>, IsolateRef?>(
      firstListenable: isolateManager.isolates,
      secondListenable: isolateManager.selectedIsolate,
      builder: (context, isolates, selectedIsolateRef, _) {
        return PopupMenuButton<IsolateRef?>(
          tooltip: 'Selected Isolate',
          initialValue: selectedIsolateRef,
          onSelected: isolateManager.selectIsolate,
          itemBuilder: (BuildContext context) =>
              isolates.where((ref) => ref != null).map(
            (ref) {
              return PopupMenuItem<IsolateRef>(
                value: ref,
                child: IsolateOption(ref!),
              );
            },
          ).toList(),
          child: IsolateOption(isolateManager.selectedIsolate.value),
        );
      },
    );
  }
}

class IsolateOption extends StatelessWidget {
  const IsolateOption(
    this.ref,
  );

  final IsolateRef? ref;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        ref?.isSystemIsolate ?? false
            ? const Icon(Icons.settings_applications)
            : const Icon(Icons.call_split),
        const SizedBox(width: denseSpacing),
        Text(
          ref == null ? 'isolate' : _isolateName(ref!),
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }

  String _isolateName(IsolateRef ref) {
    final name = ref.name;
    return '$name #${serviceManager.isolateManager.isolateIndex(ref)}';
  }
}

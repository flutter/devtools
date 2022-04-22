// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools;
import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../info/info_controller.dart';
import '../service/isolate_manager.dart';
import '../service/service_manager.dart';
import '../ui/utils.dart';
import 'common_widgets.dart';
import 'device_dialog.dart';
import 'globals.dart';
import 'screen.dart';
import 'theme.dart';
import 'utils.dart';

double get statusLineHeight => scaleByFontFactor(24.0);

/// The status line widget displayed at the bottom of DevTools.
///
/// This displays information global to the application, as well as gives pages
/// a mechanism to display page-specific information.
class StatusLine extends StatelessWidget {
  const StatusLine(this.currentScreen);

  final Screen currentScreen;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: currentScreen.showIsolateSelector,
      builder: (context, showIsolateSelector, _) {
        return Container(
          height: statusLineHeight,
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
    final isExtraNarrow = ScreenSize(context).width == MediaSize.xxs;
    final isNarrow = isExtraNarrow || ScreenSize(context).width == MediaSize.xs;
    final Widget? pageStatus = currentScreen.buildStatus(context);
    return [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: buildHelpUrlStatus(context, currentScreen, isNarrow),
        ),
      ),
      const BulletSpacer(),
      if (!isExtraNarrow && showIsolateSelector) ...[
        const IsolateSelector(),
        const BulletSpacer(),
      ],
      if (!isNarrow && pageStatus != null) ...[
        pageStatus,
        const BulletSpacer(),
      ],
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: buildConnectionStatus(context, isExtraNarrow),
        ),
      ),
    ];
  }

  Widget buildHelpUrlStatus(
    BuildContext context,
    Screen currentScreen,
    bool isNarrow,
  ) {
    final String? docPageId = currentScreen.docPageId;
    if (docPageId != null) {
      return RichText(
        text: LinkTextSpan(
          link: Link(
            display: isNarrow ? docPageId : 'flutter.dev/devtools/$docPageId',
            url: 'https://flutter.dev/devtools/$docPageId',
          ),
          onTap: () {
            ga.select(
              currentScreen.screenId,
              analytics_constants.documentationLink,
            );
          },
          context: context,
        ),
      );
    } else {
      // Use a placeholder for pages with no explicit documentation.
      return Text('${isNarrow ? '' : 'DevTools '}${devtools.version}');
    }
  }

  Widget buildConnectionStatus(BuildContext context, bool isExtraNarrow) {
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
            final VM vm = serviceManager.vm!;
            description =
                '${vm.targetCPU}-${vm.architectureBits} ${vm.operatingSystem}';
          }

          final color = textTheme.bodyText2!.color;

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
                    final flutterVersion =
                        await InfoController.getFlutterVersion();

                    unawaited(
                      showDialog(
                        context: context,
                        builder: (context) => DeviceDialog(
                          connectedApp: app,
                          flutterVersion: flutterVersion,
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
                      if (!isExtraNarrow) ...[
                        const SizedBox(width: denseSpacing),
                        Text(
                          description,
                          style: textTheme.bodyText2,
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
      child: isExtraNarrow
          ? DevToolsTooltip(
              message: noConnectionMsg,
              child: Icon(
                Icons.warning_amber_rounded,
                size: actionsIconSize,
              ),
            )
          : Text(
              noConnectionMsg,
              style: textTheme.bodyText2,
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
          child: IsolateOption(isolateManager.selectedIsolate.value),
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
          style: textTheme.bodyText2,
        ),
      ],
    );
  }

  String _isolateName(IsolateRef ref) {
    final name = ref.name;
    return '$name #${serviceManager.isolateManager.isolateIndex(ref)}';
  }
}

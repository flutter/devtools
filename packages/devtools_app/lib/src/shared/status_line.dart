// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools;
import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../info/info_controller.dart';
import '../service/isolate_manager.dart';
import '../service/service_manager.dart';
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
    final textTheme = Theme.of(context).textTheme;

    final List<Widget> children = [];

    // Have an area for page specific help (always docked to the left).
    children.add(
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: buildHelpUrlStatus(context, currentScreen, textTheme),
        ),
      ),
    );

    children.add(const BulletSpacer());

    // Display an isolate selector.
    children.add(
      ValueListenableBuilder<bool>(
        valueListenable: currentScreen.showIsolateSelector,
        builder: (context, showIsolateSelector, _) {
          return showIsolateSelector
              ? Flexible(
                  child: Row(
                    children: const [
                      Expanded(
                        child: Center(
                          child: IsolateSelector(),
                        ),
                      ),
                      BulletSpacer(),
                    ],
                  ),
                )
              : Container();
        },
      ),
    );

    // Display page specific status.
    final Widget? pageStatus =
        buildPageStatus(context, currentScreen, textTheme);

    if (pageStatus != null) {
      children.add(
        Expanded(
          child: Align(
            child: buildPageStatus(context, currentScreen, textTheme),
          ),
        ),
      );

      children.add(const BulletSpacer());
    }

    // Always display connection status (docked to the right).
    children.add(
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: buildConnectionStatus(textTheme),
        ),
      ),
    );

    return Container(
      height: statusLineHeight,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: children,
      ),
    );
  }

  Widget buildHelpUrlStatus(
    BuildContext context,
    Screen currentScreen,
    TextTheme textTheme,
  ) {
    final String? docPageId = currentScreen.docPageId;
    if (docPageId != null) {
      return RichText(
        text: LinkTextSpan(
          link: Link(
            display: 'flutter.dev/devtools/$docPageId',
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
      return const Text('DevTools ${devtools.version}');
    }
  }

  Widget? buildPageStatus(
    BuildContext context,
    Screen currentScreen,
    TextTheme textTheme,
  ) {
    return currentScreen.buildStatus(context, textTheme);
  }

  Widget buildConnectionStatus(TextTheme textTheme) {
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

          final color = Theme.of(context).textTheme.bodyText2!.color;

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
                      const SizedBox(width: denseSpacing),
                      Text(
                        description,
                        style: textTheme.bodyText2,
                        overflow: TextOverflow.clip,
                      ),
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
      child: Text(
        'No client connection',
        style: textTheme.bodyText2,
      ),
    );
  }
}

class IsolateSelector extends StatelessWidget {
  const IsolateSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final IsolateManager isolateManager = serviceManager.isolateManager;
    return DualValueListenableBuilder<List<IsolateRef?>, IsolateRef?>(
      firstListenable: isolateManager.isolates,
      secondListenable: isolateManager.selectedIsolate,
      builder: (context, isolates, selectedIsolateRef, _) {
        return DevToolsTooltip(
          message: 'Selected Isolate',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<IsolateRef?>(
              value: selectedIsolateRef,
              onChanged: isolateManager.selectIsolate,
              isDense: true,
              items: isolates.where((ref) => ref != null).map(
                (ref) {
                  return DropdownMenuItem<IsolateRef>(
                    value: ref,
                    child: Row(
                      children: [
                        ref!.isSystemIsolate ?? false
                            ? const Icon(Icons.settings_applications)
                            : const Icon(Icons.call_split),
                        const SizedBox(width: denseSpacing),
                        Text(
                          _isolateName(ref),
                          style: textTheme.bodyText2,
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        );
      },
    );
  }

  String _isolateName(IsolateRef ref) {
    final name = ref.name;
    return '$name #${serviceManager.isolateManager.isolateIndex(ref)}';
  }
}

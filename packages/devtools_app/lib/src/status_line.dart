// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import '../devtools.dart' as devtools;
import 'common_widgets.dart';
import 'device_dialog.dart';
import 'globals.dart';
import 'info/info_controller.dart';
import 'screen.dart';
import 'service_manager.dart';
import 'theme.dart';
import 'utils.dart';

const statusLineHeight = 24.0;

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
    children.add(Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: buildHelpUrlStatus(context, currentScreen, textTheme),
      ),
    ));

    children.add(const BulletSpacer());

    // Optionally display an isolate selector.
    if (currentScreen != null) {
      children.add(
        ValueListenableBuilder<bool>(
          valueListenable: currentScreen.showIsolateSelector,
          builder: (context, showIsolateSelector, _) {
            return showIsolateSelector
                ? Flexible(
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            child: buildIsolateSelector(context, textTheme),
                          ),
                        ),
                        const BulletSpacer(),
                      ],
                    ),
                  )
                : Container();
          },
        ),
      );
    }

    // Optionally display page specific status.
    if (currentScreen != null) {
      final Widget pageStatus =
          buildPageStatus(context, currentScreen, textTheme);

      if (pageStatus != null) {
        children.add(Expanded(
          child: Align(
            child: buildPageStatus(context, currentScreen, textTheme),
          ),
        ));

        children.add(const BulletSpacer());
      }
    }

    // Always display connection status (docked to the right).
    children.add(Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: buildConnectionStatus(textTheme),
      ),
    ));

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
    final colorScheme = Theme.of(context).colorScheme;

    final String docPageId = currentScreen.docPageId;
    if (docPageId != null) {
      return InkWell(
        onTap: () async {
          final url = 'https://flutter.dev/devtools/$docPageId';
          await launchUrl(url, context);
        },
        child: Text(
          'flutter.dev/devtools/$docPageId',
          style: linkTextStyle(colorScheme),
        ),
      );
    } else {
      // Use a placeholder for pages with no explicit documentation.
      return const Text('DevTools ${devtools.version}');
    }
  }

  Widget buildPageStatus(
      BuildContext context, Screen currentScreen, TextTheme textTheme) {
    return currentScreen.buildStatus(context, textTheme);
  }

  Widget buildIsolateSelector(BuildContext context, TextTheme textTheme) {
    final IsolateManager isolateManager = serviceManager.isolateManager;

    return ValueListenableBuilder(
      valueListenable: isolateManager.isolates,
      builder: (context, isolates, _) {
        return ValueListenableBuilder(
          valueListenable: isolateManager.selectedIsolate,
          builder: (context, isolateRef, _) {
            final isolates = isolateManager.isolates;

            String isolateName(IsolateRef ref) {
              final name = ref.name;
              return '$name #${isolateManager.isolateIndex(ref)}';
            }

            return DevToolsTooltip(
              tooltip: 'Selected Isolate',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<IsolateRef>(
                  value: isolateRef,
                  onChanged: isolateManager.selectIsolate,
                  isDense: true,
                  items: isolates.value.map((IsolateRef ref) {
                    return DropdownMenuItem<IsolateRef>(
                      value: ref,
                      child: Row(
                        children: [
                          ref.isSystemIsolate
                              ? const Icon(Icons.settings_applications)
                              : const Icon(Icons.call_split),
                          const SizedBox(width: denseSpacing),
                          Text(
                            isolateName(ref),
                            style: textTheme.bodyText2,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildConnectionStatus(TextTheme textTheme) {
    return ValueListenableBuilder<ConnectedState>(
      valueListenable: serviceManager.connectedState,
      builder: (context, ConnectedState connectedState, _) {
        if (connectedState.connected) {
          final app = serviceManager.connectedApp;

          String description;
          if (!app.isRunningOnDartVM) {
            description = 'web app';
          } else {
            final VM vm = serviceManager.vm;
            description =
                '${vm.targetCPU}-${vm.architectureBits} ${vm.operatingSystem}';
          }

          final color = Theme.of(context).textTheme.bodyText2.color;

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ValueListenableBuilder(
                valueListenable: serviceManager.deviceBusy,
                builder: (context, isBusy, _) {
                  return SizedBox(
                    width: smallProgressSize,
                    height: smallProgressSize,
                    child: isBusy
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          )
                        : const SizedBox(),
                  );
                },
              ),
              const SizedBox(width: denseSpacing),
              DevToolsTooltip(
                tooltip: 'Device Info',
                child: InkWell(
                  onTap: () async {
                    final flutterVersion =
                        await InfoController.getFlutterVersion();

                    unawaited(showDialog(
                      context: context,
                      builder: (context) => DeviceDialog(
                        connectedApp: app,
                        flutterVersion: flutterVersion,
                      ),
                    ));
                  },
                  child: Row(
                    children: [
                      const Icon(
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
          return Text(
            'No client connection',
            style: textTheme.bodyText2,
          );
        }
      },
    );
  }
}

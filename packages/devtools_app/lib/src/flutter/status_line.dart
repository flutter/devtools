// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools;
import '../globals.dart';
import '../service_manager.dart';
import '../utils.dart';
import 'common_widgets.dart';
import 'screen.dart';
import 'theme.dart';
import 'utils.dart';

const statusLineHeight = 24.0;

/// The status line widget displayed at the bottom of DevTools.
///
/// This displays information global to the application, as well as gives pages
/// a mechanism to display page-specific information.
class StatusLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final Screen currentScreen = Provider.of<Screen>(context);

    final List<Widget> children = [];

    // Have an area for page specific help (always docked to the left).
    children.add(Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: buildHelpUrlStatus(context, currentScreen, textTheme),
      ),
    ));
    children.add(const BulletSpacer());

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

    // Optionally display an isolate selector.
    if (currentScreen != null && currentScreen.showIsolateSelector) {
      children.add(Expanded(
        child: Align(
          child: buildIsolateSelector(context, textTheme),
        ),
      ));
      children.add(const BulletSpacer());
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
    final String docPageId = currentScreen.docPageId;
    if (docPageId != null) {
      return InkWell(
        onTap: () async {
          final url = 'https://flutter.dev/devtools/$docPageId';
          await launchUrl(url, context);
        },
        child: Text(
          'flutter.dev/devtools/$docPageId',
          style: textTheme.bodyText2.copyWith(
            decoration: TextDecoration.underline,
            color: devtoolsLink,
          ),
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

    // Listen to all isolate existence changes.
    final Stream changeStream = combineStreams(
      isolateManager.onSelectedIsolateChanged,
      isolateManager.onIsolateCreated,
      isolateManager.onIsolateExited,
    );

    return StreamBuilder<IsolateRef>(
      initialData: isolateManager.selectedIsolate,
      stream: changeStream.map((event) => isolateManager.selectedIsolate),
      builder: (BuildContext context, AsyncSnapshot<IsolateRef> snapshot) {
        final List<IsolateRef> isolates = isolateManager.isolates;

        // When we have two or more isolates with the same name, append some
        // disambiguating information.
        String disambiguatedName(IsolateRef ref) {
          String name = ref.name;
          if (isolates.where((e) => e.name == ref.name).length >= 2) {
            name = '$name (${ref.number})';
          }
          return 'isolate: $name';
        }

        return DropdownButtonHideUnderline(
          child: DropdownButton<IsolateRef>(
            value: snapshot.data,
            onChanged: (IsolateRef ref) {
              isolateManager.selectIsolate(ref?.id);
            },
            isDense: true,
            items: isolates.map((IsolateRef ref) {
              return DropdownMenuItem<IsolateRef>(
                value: ref,
                child: Text(disambiguatedName(ref), style: textTheme.bodyText2),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget buildConnectionStatus(TextTheme textTheme) {
    return StreamBuilder(
      initialData: serviceManager.service != null,
      stream: serviceManager.onStateChange,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.data) {
          final app = serviceManager.connectedApp;

          String description;
          if (!app.isRunningOnDartVM) {
            description = 'web app';
          } else {
            final VM vm = serviceManager.vm;
            description =
                '${vm.targetCPU}-${vm.architectureBits} ${vm.operatingSystem}';
          }

          // TODO(devoncarew): Add an interactive dialog to the device status
          // line.

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Device: $description',
                style: textTheme.bodyText2,
                overflow: TextOverflow.clip,
              ),
              const SizedBox(width: 2.0),
              const Icon(
                Icons.phone_android,
                size: defaultIconSize,
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

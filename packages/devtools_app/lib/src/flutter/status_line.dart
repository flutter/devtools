// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools;
import '../globals.dart';
import '../service_manager.dart';
import 'common_widgets.dart';
import 'notifications.dart';
import 'screen.dart';

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
    children.addAll([
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: buildHelpUrlStatus(context, currentScreen, textTheme),
        ),
      ),
      BulletSpacer(),
    ]);

    // Optionally display page specific status.
    if (currentScreen != null && currentScreen.providesStatus) {
      children.addAll([
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: buildPageStatus(context, currentScreen, textTheme),
          ),
        ),
        BulletSpacer(),
      ]);
    }

    // Optionally display an isolate selector.
    if (currentScreen != null && currentScreen.usesIsolateSelector) {
      children.addAll([
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: buildIsolateSelector(context, textTheme),
          ),
        ),
        BulletSpacer(),
      ]);
    }

    // Always display connection status (docked to the right).
    children.addAll([
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: buildConnectionStatus(textTheme),
        ),
      ),
    ]);

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
          // TODO(devoncarew): Shorten these urls to something like
          // 'https://flutter.dev/devtools/$docPageId'.
          final url =
              'https://flutter.dev/docs/development/tools/devtools/$docPageId';
          if (await url_launcher.canLaunch(url)) {
            await url_launcher.launch(url);
          } else {
            Notifications.of(context).push('Unable to open $url.');
          }
        },
        child: Text(
          'flutter.dev/docs/development/tools/devtools/$docPageId',
          style: textTheme.bodyText2.copyWith(
            decoration: TextDecoration.underline,
          ),
        ),
      );
    } else {
      // Use a placeholder for pages with no explicit documentation.
      return Text('DevTools ${devtools.version}');
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

        // When we have two or more isolates with the same name, append dome
        // disambiguating information.
        String disambiguatedName(IsolateRef ref) {
          String name = ref.name;
          if (isolates.where((e) => e.name == ref.name).length >= 2) {
            name = '$name (${ref.number})';
          }
          return 'isolate: $name';
        }

        return DropdownButton<IsolateRef>(
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

          return Text(
            'Connected ($description)',
            style: textTheme.bodyText2,
            overflow: TextOverflow.clip,
            //maxLines: 1,
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

Stream combineStreams(Stream a, Stream b, Stream c) {
  StreamController controller;

  StreamSubscription asub;
  StreamSubscription bsub;
  StreamSubscription csub;

  controller = StreamController(
    onListen: () {
      asub = a.listen(controller.add);
      bsub = b.listen(controller.add);
      csub = c.listen(controller.add);
    },
    onCancel: () {
      asub?.cancel();
      bsub?.cancel();
      csub?.cancel();
    },
  );

  return controller.stream;
}

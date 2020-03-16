// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

/// The status line widget displayed at the bottom of DevTools.
class StatusLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO(devoncarew): Break this into an isolates area, a connection status
    // area, a page specific area, and a documentation link area.

    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 24.0,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: buildIsolateSelector(textTheme),
            ),
          ),
          BulletSpacer(),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: buildPageStatus(textTheme),
            ),
          ),
          BulletSpacer(),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: buildConnectionStatus(textTheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildIsolateSelector(TextTheme textTheme) {
    // TODO: isolate selector

    // TODO: only applies to certain pages

    // todo: listen to more changes

    return StreamBuilder(
      initialData: serviceManager.isolateManager.selectedIsolate,
      stream: serviceManager.isolateManager.onSelectedIsolateChanged,
      builder: (BuildContext context, AsyncSnapshot<IsolateRef> snapshot) {
        final vmService = serviceManager.service;

        return Text(
          '${snapshot.data?.id}',
          style: textTheme.bodyText2,
          overflow: TextOverflow.clip,
        );
      },
    );
  }

  Widget buildPageStatus(TextTheme textTheme) {
    // TODO: show page status for the current page

    return Text(
      'todo: page status',
      style: textTheme.bodyText2,
    );
  }

  Widget buildConnectionStatus(TextTheme textTheme) {
    // TODO: show connection status

    return StreamBuilder(
      initialData: serviceManager.service != null,
      stream: serviceManager.onStateChange,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.data) {
          final vmService = serviceManager.service;
          final uri = vmService.connectedUri;

          // todo: include flutter, dart vm, flutter web, web, ...

          return Text(
            'Connected to ${uri.host}:${uri.port}',
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

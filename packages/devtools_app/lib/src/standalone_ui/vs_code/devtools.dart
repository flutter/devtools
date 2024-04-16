// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/screen.dart';
import '../api/vs_code_api.dart';

class DevToolsSidebarOptions extends StatelessWidget {
  const DevToolsSidebarOptions({
    required this.api,
    super.key,
  });

  final VsCodeApi api;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DevTools',
          style: theme.textTheme.titleMedium,
        ),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final screen
                in ScreenMetaData.values.where(_shouldIncludeScreen))
              _createDevToolsScreenRow(
                label: screen.title ?? screen.id,
                icon: screen.icon!,
                screenId: screen.id,
                api: api,
                theme: theme,
              ),
            if (api.capabilities.openDevToolsExternally)
              _createDevToolsScreenRow(
                label: 'Open in Browser',
                icon: Icons.open_in_browser,
                api: api,
                theme: theme,
                onPressed: () {
                  ga.select(
                    gac.VsCodeFlutterSidebar.id,
                    gac.VsCodeFlutterSidebar.openDevToolsExternally.name,
                  );
                  unawaited(api.openDevToolsPage(null, forceExternal: true));
                },
              ),
          ],
        ),
        const PaddedDivider.thin(),
        const Padding(
          padding: EdgeInsets.only(left: borderPadding),
          child: Text(
            'Begin a debug session to use tools that require a running '
            'application.',
          ),
        ),
      ],
    );
  }

  bool _shouldIncludeScreen(ScreenMetaData screen) {
    return switch (screen) {
      ScreenMetaData.home => false,
      ScreenMetaData.vmTools => false,
      // The performance and cpu profiler pages just show an option to load
      // offline data. Hide them as they aren't that useful without a running
      // app.
      ScreenMetaData.performance => false,
      ScreenMetaData.cpuProfiler => false,
      _ => !screen.requiresConnection,
    };
  }
}

TableRow _createDevToolsScreenRow({
  required String label,
  required IconData icon,
  required VsCodeApi api,
  required ThemeData theme,
  String? screenId,
  void Function()? onPressed,
}) {
  assert(
    screenId != null || onPressed != null,
    'screenId and onPressed cannot both be null',
  );
  final color = theme.colorScheme.secondary;
  return TableRow(
    children: [
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            shape: const ContinuousRectangleBorder(),
            textStyle: theme.regularTextStyle,
          ),
          icon: Icon(
            icon,
            size: actionsIconSize,
            color: color,
          ),
          label: Text(
            label,
            style: theme.regularTextStyle.copyWith(color: color),
          ),
          onPressed: onPressed ??
              () {
                ga.select(
                  gac.VsCodeFlutterSidebar.id,
                  gac.VsCodeFlutterSidebar.openDevToolsScreen(screenId!),
                );
                unawaited(api.openDevToolsPage(null, page: screenId));
              },
        ),
      ),
    ],
  );
}

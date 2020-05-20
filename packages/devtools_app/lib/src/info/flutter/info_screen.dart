// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../version.dart';
import '../info_controller.dart';

class InfoScreen extends Screen {
  const InfoScreen()
      : super(
          'info',
          title: 'Info',
          icon: Octicons.info,
        );

  @override
  bool get showIsolateSelector => true;

  @override
  Widget build(BuildContext context) {
    return !serviceManager.connectedApp.isDartWebAppNow
        ? const InfoScreenBody()
        : const DisabledForWebAppMessage();
  }

  /// The key to identify the flutter version view.
  @visibleForTesting
  static const Key flutterVersionKey = Key('Info Screen Flutter Version');

  /// The key to identify the flag list view
  @visibleForTesting
  static const Key flagListKey = Key('Info Screen Flag List');
}

class InfoScreenBody extends StatefulWidget {
  const InfoScreenBody();

  @override
  _InfoScreenBodyState createState() => _InfoScreenBodyState();
}

class _InfoScreenBodyState extends State<InfoScreenBody> {
  InfoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = InfoController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected App',
          style: textTheme.headline5,
        ),
        const PaddedDivider(padding: EdgeInsets.only(top: 4.0)),
        ValueListenableBuilder(
          valueListenable: _controller.flutterVersion,
          builder: (context, version, _) =>
              version == null ? const SizedBox() : _VersionInformation(version),
        ),
        const Padding(padding: EdgeInsets.only(top: defaultSpacing)),
        Text(
          'VM Flag List',
          style: textTheme.headline5,
        ),
        const PaddedDivider(padding: EdgeInsets.only(top: 4.0)),
        Expanded(
          child: ValueListenableBuilder<FlagList>(
            valueListenable: _controller.flagListNotifier,
            builder: (context, flagList, _) {
              if (flagList == null || flagList.flags.isEmpty) {
                return const SizedBox();
              }
              return _FlagList(flagList);
            },
          ),
        ),
      ],
    );
  }
}

class _VersionInformation extends StatelessWidget {
  const _VersionInformation(this.flutterVersion);

  final FlutterVersion flutterVersion;

  @override
  Widget build(BuildContext context) {
    const boldText = TextStyle(fontWeight: FontWeight.bold);

    final versions = {
      'Flutter': flutterVersion.version,
      'Framework': flutterVersion.frameworkRevision,
      'Engine': flutterVersion.engineRevision,
      'Dart': flutterVersion.dartSdkVersion,
    };

    return Column(
      key: InfoScreen.flutterVersionKey,
      children: [
        for (var name in versions.keys)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              children: [
                Text('$name ', style: boldText),
                Text(versions[name]),
              ],
            ),
          ),
      ],
    );
  }
}

class _FlagList extends StatelessWidget {
  const _FlagList(this.flagList);

  final FlagList flagList;

  @override
  Widget build(BuildContext context) {
    final defaultTextTheme = DefaultTextStyle.of(context).style;
    return Scrollbar(
      child: ListView.builder(
        key: InfoScreen.flagListKey,
        itemCount: flagList?.flags?.length ?? 0,
        itemBuilder: (context, index) {
          final flag = flagList.flags[index];
          final modifiedStatusText = flag.modified ? '(modified) ' : '';
          return Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flag.name, style: semibold(defaultTextTheme)),
                      Flexible(
                          child: Text(
                        ' ${flag.comment}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                    ],
                  ),
                ),
                Text(
                  ' $modifiedStatusText${flag.valueAsString}',
                  textAlign: TextAlign.end,
                  style: defaultTextTheme,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

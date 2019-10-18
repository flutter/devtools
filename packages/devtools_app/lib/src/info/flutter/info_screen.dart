// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:vm_service/vm_service.dart';

import '../../../devtools.dart' as devtools;
import '../../flutter/common_widgets.dart';
import '../../flutter/screen.dart';
import '../../version.dart';
import '../info_controller.dart';

class InfoScreen extends Screen {
  const InfoScreen() : super('Info');

  @override
  Widget build(BuildContext context) => InfoScreenBody();

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      icon: Icon(Octicons.getIconData('info')),
      text: 'Info',
    );
  }

  /// The key to identify the flag list view
  @visibleForTesting
  static const Key flagListKey = Key('Info Screen Flag List');

  /// The key to identify the flutter version view.
  @visibleForTesting
  static const Key flutterVersionKey = Key('Info Screen Flutter Version');
}

class InfoScreenBody extends StatefulWidget {
  @override
  _InfoScreenBodyState createState() => _InfoScreenBodyState();
}

class _InfoScreenBodyState extends State<InfoScreenBody> {
  FlutterVersion _flutterVersion;

  FlagList _flagList;

  @override
  void initState() {
    super.initState();
    InfoController(
      onFlagListChanged: (flagList) => setState(() {
        _flagList = flagList;
      }),
      onFlutterVersionChanged: (flutterVersion) => setState(() {
        _flutterVersion = flutterVersion;
      }),
    )..entering();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version Information',
          style: textTheme.headline,
        ),
        const PaddedDivider(),
        if (_flutterVersion != null) _VersionInformation(_flutterVersion),
        const Padding(padding: EdgeInsets.only(top: 16.0)),
        Text(
          'Dart VM Flag List',
          style: textTheme.headline,
        ),
        const PaddedDivider(padding: EdgeInsets.only(top: 4.0, bottom: 0.0)),
        if (_flagList != null)
          Expanded(
            child: _FlagList(_flagList),
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
    return DefaultTaggedText(
      '<bold>Flutter: </bold>${flutterVersion.flutterVersionSummary}\n'
      '<bold>Framework: </bold>${flutterVersion.frameworkVersionSummary}\n'
      '<bold>Engine: </bold>${flutterVersion.engineVersionSummary}\n'
      '<bold>Dart SDK: </bold>${flutterVersion.dartSdkVersion}\n'
      '<bold>DevTools: </bold>${devtools.version}\n',
      key: InfoScreen.flutterVersionKey,
    );
  }
}

class _FlagList extends StatelessWidget {
  const _FlagList(this.flagList);

  final FlagList flagList;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: InfoScreen.flagListKey,
      itemCount: flagList?.flags?.length ?? 0,
      itemBuilder: (context, index) {
        final flag = flagList.flags[index];
        final modifiedStatusText = flag.modified ? 'modified' : 'default';
        return Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: DefaultTaggedText(
                  '<bold>${flag.name}</bold>\n'
                  '${flag.comment}',
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 100.0),
                child: DefaultTaggedText(
                  '<primary-color>${flag.valueAsString}</primary-color>\n'
                  '<primary-color-light>$modifiedStatusText</primary-color-light>',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

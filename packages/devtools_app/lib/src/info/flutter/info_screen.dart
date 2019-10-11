// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
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
      icon: Icon(Icons.info),
      text: 'Info',
    );
  }
}

class InfoScreenBody extends StatefulWidget {
  @override
  _InfoScreenBodyState createState() => _InfoScreenBodyState();
}

class _InfoScreenBodyState extends State<InfoScreenBody> {
  InfoController _infoController;
  FlutterVersion _flutterVersion;
  FlagList _flagList;

  @override
  void initState() {
    super.initState();
    _flutterVersion = null;
    _flagList = null;
    _infoController = InfoController(
      onFlagListChanged: (flagList) => setState(() {
        _flagList = flagList;
      }),
      onFlutterVersionChanged: (flutterVersion) => setState(() {
        _flutterVersion = flutterVersion;
      }),
    )..entering();
  }

  @override
  void dispose() {
    super.dispose();
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
        _buildVersionInformation(context),
        const Padding(padding: EdgeInsets.only(top: 16.0)),
        Text(
          'Dart VM Flag List',
          style: textTheme.headline,
        ),
        const PaddedDivider(padding: EdgeInsets.only(top: 4.0, bottom: 0.0)),
        Expanded(
          child: _buildFlagList(context),
        )
      ],
    );
  }

  Widget _buildVersionInformation(BuildContext context) {
    final span = TextSpanUtil(context);
    return span.richText(children: [
      span.bold('Flutter: '),
      span.normal(_flutterVersion?.flutterVersionSummary ?? ''),
      span.newline,
      span.bold('Framework: '),
      span.normal(_flutterVersion?.frameworkVersionSummary),
      span.newline,
      span.bold('Engine: '),
      span.normal(_flutterVersion?.engineVersionSummary),
      span.newline,
      span.bold('Dart SDK: '),
      span.normal(_flutterVersion?.dartSdkVersion),
      span.newline,
      span.bold('DevTools: '),
      span.normal(devtools.version),
    ]);
  }

  Widget _buildFlagList(BuildContext context) {
    final span = TextSpanUtil(context);
    return ListView.builder(
      itemCount: _flagList?.flags?.length ?? 0,
      itemBuilder: (context, index) {
        final flag = _flagList.flags[index];
        return Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: span.richText(children: [
                  span.bold(flag.name),
                  span.newline,
                  span.normal(flag.comment),
                ]),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 100.0),
                child: span.richText(textAlign: TextAlign.end, children: [
                  span.normal(flag.valueAsString,
                      color: span.theme.primaryColor),
                  span.newline,
                  span.light(flag.modified ? 'modified' : 'default',
                      color: span.theme.primaryColorLight),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A utility for creating styled [TextSpan]s in a [RichText] widget.
class TextSpanUtil {
  TextSpanUtil(BuildContext context) : theme = Theme.of(context);
  final ThemeData theme;

  TextSpan _span(String text, FontWeight weight, Color color) => TextSpan(
      text: text,
      style: theme.textTheme.body1.copyWith(fontWeight: weight, color: color));
  TextSpan bold(String text, {Color color}) =>
      _span(text, FontWeight.w600, color ?? theme.textTheme.body1.color);
  TextSpan normal(String text, {Color color}) =>
      _span(text, FontWeight.normal, color ?? theme.textTheme.body1.color);
  TextSpan light(String text, {Color color}) =>
      _span(text, FontWeight.w300, color ?? theme.textTheme.body1.color);
  TextSpan get newline =>
      _span('\n', FontWeight.normal, theme.colorScheme.onBackground);

  RichText richText(
      {TextAlign textAlign = TextAlign.start,
      TextOverflow textOverflow = TextOverflow.visible,
      @required List<TextSpan> children}) {
    assert(children != null);
    return RichText(
      softWrap: true,
      overflow: textOverflow,
      text: TextSpan(text: '', children: children),
      textAlign: textAlign,
    );
  }
}

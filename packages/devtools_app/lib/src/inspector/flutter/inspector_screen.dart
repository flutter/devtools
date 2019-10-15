// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../../flutter/screen.dart';
import '../../service_extensions.dart' as extensions;
import '../../ui/flutter/service_extension_widgets.dart';

class InspectorScreen extends Screen {
  const InspectorScreen() : super('Info');

  @override
  Widget build(BuildContext context) => InspectorScreenBody();

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      icon: Icon(Octicons.getIconData('device-mobile')),
      text: 'Flutter Inspector',
    );
  }
}

class InspectorScreenBody extends StatefulWidget {
  @override
  _InspectorScreenBodyState createState() => _InspectorScreenBodyState();
}

class _InspectorScreenBodyState extends State<InspectorScreenBody> {
  @override
  void initState() {
    super.initState();
    // TODO(jacobr): actually add the Inspector Controller.
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ServiceExtensionButtonGroup(
          extensions: [extensions.toggleSelectWidgetMode],
        ),
        // TODO(jacobr): add the refresh tree button here.
        /*
          RaisedButton(
              child: IconAndText('Refresh Tree', FlutterIcons.refresh)
            onClick: _refreshInspector
          ),

           */
        ...getServiceExtensionWidgets()
      ],
    );
  }
}

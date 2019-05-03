// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/inspector/flutter/inspector_tree_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import 'package:vm_service/vm_service.dart' hide Stack;

import '../inspector_controller.dart';
import '../inspector_service.dart';
import '../../flutter/screen.dart';
import '../../globals.dart';
import '../../service_extensions.dart' as extensions;
import '../../ui/flutter/service_extension_widgets.dart';

final GlobalKey<InspectorTreeStateFlutter> summaryTreeKey = GlobalKey(debugLabel: 'Summary Tree');
final GlobalKey<InspectorTreeStateFlutter> detailsTreeKey = GlobalKey(debugLabel: 'Details Tree');

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
  bool actionInProgress = false;
  bool _expandCollapseSupported = false;
  bool connectionInProgress = false;
  InspectorService inspectorService;

  InspectorController inspectorController;
  bool displayedWidgetTrackingNotice = false;

  bool get enableButtons => actionInProgress == false && connectionInProgress == false;

  @override
  void initState() {
    super.initState();
    // TODO(jacobr): support analytics.
    // ga_platform.setupDimensions();
    // TODO(jacobr): actually add the Inspector Controller.

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  void _onExpandClick() {
    blockWhileInProgress(
      inspectorController.expandAllNodesInDetailsTree
    );
  }

  void _onResetClick() {
    blockWhileInProgress(
     inspectorController.collapseDetailsToSelected
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: <Widget>[
                ServiceExtensionButtonGroup(
                  extensions: [extensions.toggleSelectWidgetMode],
                ),
              ],
              // TODO(jacobr): add the refresh tree button here.
              /*
              RaisedButton(
                  child: IconAndText('Refresh Tree', FlutterIcons.refresh)
                onClick: _refreshInspector
              ),

               */
            ),
            Row(
              children: getServiceExtensionWidgets(),
            )
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InspectorTreeFlutter(key: summaryTreeKey),
            Stack(
              children: [
                InspectorTreeFlutter(key: detailsTreeKey),
                if (_expandCollapseSupported) Row(children: [
                FloatingActionButton(
                  onPressed: enableButtons ? _onExpandClick : null,
                  child: const Text('Expand all'),
                ),
                FloatingActionButton(
                  onPressed: enableButtons ? _onResetClick : null,
                  child: const Text('Collapse to selected'),
                )])
              ],
            )
          ],
        ),
      ],
    );
  }

  void _onExpandCollapseSupported() {
    setState(() {
      _expandCollapseSupported = true;
    });
  }

  void _handleConnectionStart(VmService service) async {
    setState(() {
      connectionInProgress = true;
    });

    try {
      await ensureInspectorServiceDependencies();

      // Init the inspector service, or return null.
      inspectorService =
      await InspectorService.create(service).catchError((e) => null);
    } finally {
      setState(() {
        connectionInProgress = false;
      });
    }

    if (inspectorService == null) {
      return;
    }

    // TODO(jacobr): support the Render tree, Layer tree, and Semantic trees as
    // well as the widget tree.

    InspectorTreeStateFlutter createTree() {
      throw 'Impl tree states';
      return null;
    }

    setState(() {
      inspectorController = InspectorController(
        inspectorTree: createTree(),
        detailsTree: createTree(),
        inspectorService: inspectorService,
        treeType: FlutterTreeType.widget,
        onExpandCollapseSupported: _onExpandCollapseSupported,
      );
      final InspectorTreeStateFlutter inspectorTree =
          inspectorController.inspectorTree;
      final InspectorTreeStateFlutter detailsInspectorTree =
          inspectorController.details.inspectorTree;

      // TODO(jacobr): update visibility based on whether the screen is visible.
      // That will reduce memory usage on the device running a Flutter application
      // when the inspector panel is not visible.
      inspectorController.setVisibleToUser(true);
      inspectorController.setActivate(true);

      // TODO(devoncarew): Move this notice display to once a day.
      if (!displayedWidgetTrackingNotice) {
        // ignore: unawaited_futures
        inspectorService.isWidgetCreationTracked().then((bool value) {
          if (value) {
            return;
          }

          displayedWidgetTrackingNotice = true;
          // TODO(jacobr): implement showMessage
          /*
          framework.showMessage(
            message: trackWidgetCreationWarning,
            screenId: inspectorScreenId,
          );
           */
        });
      }
    });
  }

  void _handleConnectionStop(dynamic event) {
    inspectorController?.setActivate(false);
    inspectorController?.dispose();
    setState(() {
      inspectorController = null;
    });
  }

  void _refreshInspector() {
    // TODO(jacobr): support analytics.
    // ga.select(ga.inspector, ga.refresh);
    blockWhileInProgress(() async {
      await inspectorController?.onForceRefresh();
    });
  }

  void blockWhileInProgress(Future callback()) async {
    setState(() {
      actionInProgress = true;
    });
    try {
      // TODO(jacobr): also support timing out.
      await callback();
    } finally {
      setState(() {
        actionInProgress = false;
      });
    }
  }
}

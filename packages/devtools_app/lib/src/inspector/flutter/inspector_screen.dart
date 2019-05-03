// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/blocking_action_mixin.dart';
import '../../flutter/screen.dart';
import '../../globals.dart';
import '../../service_extensions.dart' as extensions;
import '../../ui/flutter/label.dart';
import '../../ui/flutter/service_extension_widgets.dart';
import '../../ui/icons.dart';
import '../flutter_widget.dart';
import '../inspector_controller.dart';
import '../inspector_service.dart';
import 'inspector_tree_flutter.dart';

class InspectorScreen extends Screen {
  const InspectorScreen() : super('Info');

  @override
  Widget build(BuildContext context) => const InspectorScreenBody();

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      icon: Icon(Octicons.getIconData('device-mobile')),
      text: 'Flutter Inspector',
    );
  }
}

class InspectorScreenBody extends StatefulWidget {
  const InspectorScreenBody();

  @override
  _InspectorScreenBodyState createState() => _InspectorScreenBodyState();
}

class _InspectorScreenBodyState extends State<InspectorScreenBody>
    with BlockingActionMixin, AutoDisposeMixin {
  bool _expandCollapseSupported = false;
  bool connectionInProgress = false;
  InspectorService inspectorService;

  InspectorController inspectorController;
  InspectorTreeControllerFlutter summaryTreeController;
  InspectorTreeControllerFlutter detailsTreeController;
  bool displayedWidgetTrackingNotice = false;

  bool get enableButtons =>
      actionInProgress == false && connectionInProgress == false;

  @override
  void initState() {
    super.initState();
    // TODO(jacobr): support analytics.
    // ga_platform.setupDimensions();
    // TODO(jacobr): actually add the Inspector Controller.

    autoDispose(
        serviceManager.onConnectionAvailable.listen(_handleConnectionStart));
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    autoDispose(
        serviceManager.onConnectionClosed.listen(_handleConnectionStop));
  }

  @override
  void dispose() {
    super.dispose();
    inspectorService.dispose();
    inspectorService = null;
  }

  void _onExpandClick() {
    blockWhileInProgress(inspectorController.expandAllNodesInDetailsTree);
  }

  void _onResetClick() {
    blockWhileInProgress(inspectorController.collapseDetailsToSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ServiceExtensionButtonGroup(
              extensions: [extensions.toggleSelectWidgetMode],
            ),
            OutlineButton(
              child: Label(FlutterIcons.refresh, 'Refresh Tree'),
              onPressed: _refreshInspector,
            ),
            const Spacer(),
            ...getServiceExtensionWidgets(),
          ],
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                  child: InspectorTree(
                controller: summaryTreeController,
              )),
              Expanded(
                child: Stack(
                  children: [
                    InspectorTree(
                      controller: detailsTreeController,
                    ),
                    if (_expandCollapseSupported)
                      Row(
                        children: <Widget>[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            // Workaround as outline buttons are transparent by
                            // default.
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: Row(
                              children: [
                                OutlineButton(
                                  onPressed:
                                      enableButtons ? _onExpandClick : null,
                                  child: const Text('Expand all'),
                                ),
                                OutlineButton(
                                  onPressed:
                                      enableButtons ? _onResetClick : null,
                                  child: const Text('Collapse to selected'),
                                )
                              ],
                            ),
                          ),
                        ],
                      )
                  ],
                ),
              )
            ],
          ),
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
      // TODO(jacobr): move this rootBundle loading code into
      // InspectorController once the dart:html app is removed and Flutter
      // conventions for loading assets can be the default.
      if (Catalog.instance == null) {
        final json = await rootBundle.loadString('web/widgets.json');
        // ignore: invalid_use_of_visible_for_testing_member
        Catalog.setCatalog(Catalog.decode(json));
      }
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

    setState(() {
      summaryTreeController = InspectorTreeControllerFlutter();
      detailsTreeController = InspectorTreeControllerFlutter();
      inspectorController = InspectorController(
        inspectorTree: summaryTreeController,
        detailsTree: detailsTreeController,
        inspectorService: inspectorService,
        treeType: FlutterTreeType.widget,
        onExpandCollapseSupported: _onExpandCollapseSupported,
      );

      // TODO(jacobr): update visibility based on whether the screen is visible.
      // That will reduce memory usage on the device running a Flutter
      // application when the inspector panel is not visible.
      inspectorController.setVisibleToUser(true);
      inspectorController.setActivate(true);

      // TODO(jacobr): move this notice display to once a day.
      if (!displayedWidgetTrackingNotice) {
        // ignore: unawaited_futures
        inspectorService.isWidgetCreationTracked().then((bool value) {
          if (value) {
            return;
          }

          displayedWidgetTrackingNotice = true;
          // TODO(jacobr): implement showMessage.
          // framework.showMessage(
          //  message: trackWidgetCreationWarning,
          //  screenId: inspectorScreenId,
          //);
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
}

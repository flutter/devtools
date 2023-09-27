// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../../shared/diagnostics/diagnostics_node.dart';
import '../../../../shared/diagnostics/inspector_service.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/utils.dart';
import '../../inspector_controller.dart';
import '../../inspector_data_models.dart';
import 'utils.dart';

const maxRequestsPerSecond = 3.0;

/// Base class for layout widgets for all widget types.
abstract class LayoutExplorerWidget extends StatefulWidget {
  const LayoutExplorerWidget(
    this.inspectorController, {
    Key? key,
  }) : super(key: key);

  final InspectorController inspectorController;
}

/// Base class for state objects for layout widgets for all widget types.
abstract class LayoutExplorerWidgetState<W extends LayoutExplorerWidget,
        L extends LayoutProperties> extends State<W>
    with TickerProviderStateMixin
    implements InspectorServiceClient {
  LayoutExplorerWidgetState() {
    _onSelectionChangedCallback = onSelectionChanged;
  }

  late AnimationController entranceController;
  late CurvedAnimation entranceCurve;
  late AnimationController changeController;

  late CurvedAnimation changeAnimation;

  L? _previousProperties;

  L? _properties;

  InspectorObjectGroupManager? objectGroupManager;

  AnimatedLayoutProperties<L>? get animatedProperties => _animatedProperties;
  AnimatedLayoutProperties<L>? _animatedProperties;

  L? get properties =>
      _previousProperties ?? _animatedProperties as L? ?? _properties;

  RemoteDiagnosticsNode? get selectedNode =>
      inspectorController.selectedNode.value?.diagnostic;

  InspectorController get inspectorController => widget.inspectorController;

  InspectorService? get inspectorService =>
      serviceConnection.inspectorService as InspectorService?;

  late RateLimiter rateLimiter;

  late Future<void> Function() _onSelectionChangedCallback;

  Future<void> onSelectionChanged() async {
    if (!mounted) return;
    final selectedNodeLocal = selectedNode;
    if (selectedNodeLocal == null) return;
    if (!shouldDisplay(selectedNodeLocal)) return;
    final prevRootId = id(_properties?.node);
    final newRootId = id(getRoot(selectedNodeLocal));
    final shouldFetch = prevRootId != newRootId;
    if (shouldFetch) {
      _dirty = false;
      final newSelection = await fetchLayoutProperties();
      _setProperties(newSelection);
    } else {
      updateHighlighted(_properties);
    }
  }

  /// Whether this layout explorer can work with this kind of node.
  bool shouldDisplay(RemoteDiagnosticsNode node);

  List<LayoutProperties> get children => properties!.displayChildren;

  LayoutProperties? highlighted;

  /// Returns the root widget to show.
  ///
  /// For cases such as Flex widgets or in the future ListView widgets we may
  /// want to show the layout for all widgets under a root that is the parent
  /// of the current widget.
  RemoteDiagnosticsNode? getRoot(RemoteDiagnosticsNode? node);

  Future<L?> fetchLayoutProperties() async {
    objectGroupManager?.cancelNext();
    final manager = objectGroupManager!;
    final nextObjectGroup = manager.next;
    final node = await nextObjectGroup.getLayoutExplorerNode(
      getRoot(selectedNode),
    );
    if (node == null || node.renderObject == null) return null;

    if (!nextObjectGroup.disposed) {
      assert(manager.next == nextObjectGroup);
      manager.promoteNext();
    }
    return computeLayoutProperties(node);
  }

  L computeLayoutProperties(RemoteDiagnosticsNode node);

  AnimatedLayoutProperties<L> computeAnimatedProperties(L nextProperties);

  void updateHighlighted(L? newProperties);

  String? id(RemoteDiagnosticsNode? node) => node?.valueRef.id;

  void _registerInspectorControllerService() {
    inspectorController.selectedNode.addListener(_onSelectionChangedCallback);
    inspectorService?.addClient(this);
  }

  void _unregisterInspectorControllerService() {
    inspectorController.selectedNode
        .removeListener(_onSelectionChangedCallback);
    inspectorService?.removeClient(this);
  }

  @override
  void initState() {
    super.initState();
    rateLimiter = RateLimiter(maxRequestsPerSecond, refresh);
    _registerInspectorControllerService();
    _initAnimationStates();
    _updateObjectGroupManager();
    // TODO(jacobr): put inspector controller in Controllers and
    // update on didChangeDependencies.
    _animateProperties();
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateObjectGroupManager();
    _animateProperties();
    if (oldWidget.inspectorController != inspectorController) {
      _unregisterInspectorControllerService();
      _registerInspectorControllerService();
    }
  }

  @override
  void dispose() {
    entranceController.dispose();
    changeController.dispose();
    _unregisterInspectorControllerService();
    super.dispose();
  }

  void _animateProperties() {
    if (_animatedProperties != null) {
      changeController.forward();
    }
    if (_previousProperties != null) {
      entranceController.reverse();
    } else {
      entranceController.forward();
    }
  }

  // update selected widget in the device without triggering selection listener event.
  // this is required so that we don't change focus
  //   when tapping on a child is also Flex-based widget.
  Future<void> setSelectionInspector(RemoteDiagnosticsNode node) async {
    final service = node.objectGroupApi;
    if (service != null && service is ObjectGroup) {
      await service.setSelectionInspector(node.valueRef, false);
    }
  }

  // update selected widget and trigger selection listener event to change focus.
  void refreshSelection(RemoteDiagnosticsNode node) {
    inspectorController.refreshSelection(node, node, true);
  }

  Future<void> onTap(LayoutProperties properties) async {
    setState(() => highlighted = properties);
    await setSelectionInspector(properties.node);
  }

  void onDoubleTap(LayoutProperties properties) {
    refreshSelection(properties.node);
  }

  Future<void> refresh() async {
    if (!_dirty) return;
    _dirty = false;
    final updatedProperties = await fetchLayoutProperties();
    if (updatedProperties != null) {
      _changeProperties(updatedProperties);
    }
  }

  void _changeProperties(L nextProperties) {
    if (!mounted) return;
    updateHighlighted(nextProperties);
    setState(() {
      _animatedProperties = computeAnimatedProperties(nextProperties);
      changeController.forward(from: 0.0);
    });
  }

  void _setProperties(L? newProperties) {
    if (!mounted) return;
    updateHighlighted(newProperties);
    if (_properties == newProperties) {
      return;
    }
    setState(() {
      _previousProperties ??= _properties;
      _properties = newProperties;
    });
    _animateProperties();
  }

  void _initAnimationStates() {
    entranceController = longAnimationController(
      this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          setState(() {
            _previousProperties = null;
            entranceController.forward();
          });
        }
      });
    entranceCurve = defaultCurvedAnimation(entranceController);
    changeController = longAnimationController(this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _properties = _animatedProperties!.end;
            _animatedProperties = null;
            changeController.value = 0.0;
          });
        }
      });
    changeAnimation = defaultCurvedAnimation(changeController);
  }

  void _updateObjectGroupManager() {
    final service = serviceConnection.inspectorService;
    if (service != objectGroupManager?.inspectorService) {
      objectGroupManager = InspectorObjectGroupManager(
        service as InspectorService,
        'flex-layout',
      );
    }
    unawaited(onSelectionChanged());
  }

  bool _dirty = false;

  @override
  void onFlutterFrame() {
    if (!mounted) return;
    if (_dirty) {
      rateLimiter.scheduleRequest();
    }
  }

  // TODO(albertusangga): Investigate why onForceRefresh is not getting called.
  @override
  Future<void> onForceRefresh() async {
    final properties = await fetchLayoutProperties();
    if (properties != null) {
      _setProperties(properties);
    }
  }

  /// Currently this is not working so we should listen to controller selection event instead.
  @override
  Future<void> onInspectorSelectionChanged() async {}

  /// Register callback to be executed once Flutter frame is ready.
  void markAsDirty() {
    _dirty = true;
  }
}

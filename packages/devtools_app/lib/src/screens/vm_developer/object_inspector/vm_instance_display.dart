// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/console/widgets/expandable_variable.dart';
import '../../../shared/diagnostics/dart_object_node.dart';
import '../../../shared/diagnostics/tree_builder.dart';
import '../../../shared/globals.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/colors.dart';
import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

class VmInstanceDisplay extends StatefulWidget {
  const VmInstanceDisplay({
    super.key,
    required this.controller,
    required this.instance,
  });

  final ObjectInspectorViewController controller;
  final InstanceObject instance;

  @override
  State<StatefulWidget> createState() => _VmInstanceDisplayState();
}

class _VmInstanceDisplayState extends State<VmInstanceDisplay> {
  late Future<void> _initialized;
  late DartObjectNode _root;

  @override
  void initState() {
    super.initState();
    _populate();
  }

  @override
  void didUpdateWidget(VmInstanceDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.instance == oldWidget.instance) {
      return;
    }
    _populate();
  }

  void _populate() {
    final isolateRef =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
    _root = DartObjectNode.fromValue(
      name: 'value',
      value: widget.instance.obj,
      isolateRef: isolateRef,
      artificialName: true,
    );

    unawaited(
      _initialized = buildVariablesTree(_root)
          .then(
            (_) => _root.expand(),
          )
          .then(
            (_) => unawaited(
              Future.wait([
                for (final child in _root.children) buildVariablesTree(child),
              ]),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SplitPane(
      axis: Axis.vertical,
      initialFractions: const [0.5, 0.5],
      children: [
        OutlineDecoration.onlyBottom(
          child: _InstanceViewer(
            controller: widget.controller,
            instance: widget.instance,
          ),
        ),
        OutlineDecoration.onlyTop(
          child: Column(
            children: [
              const AreaPaneHeader(
                title: Text('Properties'),
                includeTopBorder: false,
              ),
              Flexible(
                child: FutureBuilder(
                  future: _initialized,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const CenteredCircularProgressIndicator();
                    }
                    return ExpandableVariable(
                      variable: _root,
                      dataDisplayProvider: (variable, onPressed) {
                        return DisplayProvider(
                          controller: widget.controller,
                          variable: variable,
                          onTap: onPressed,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstanceViewer extends StatelessWidget {
  const _InstanceViewer({
    required this.controller,
    required this.instance,
  });

  final ObjectInspectorViewController controller;
  final InstanceObject instance;

  @override
  Widget build(BuildContext context) {
    return VmObjectDisplayBasicLayout(
      controller: controller,
      object: instance,
      generalDataRows: [
        serviceObjectLinkBuilderMapEntry(
          controller: controller,
          key: 'Object Class',
          object: instance.obj.classRef!,
        ),
        shallowSizeRowBuilder(instance),
        reachableSizeRowBuilder(instance),
        retainedSizeRowBuilder(instance),
      ],
    );
  }
}

class DisplayProvider extends StatelessWidget {
  const DisplayProvider({
    super.key,
    required this.variable,
    required this.onTap,
    required this.controller,
  });

  final DartObjectNode variable;
  final VoidCallback onTap;
  final ObjectInspectorViewController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (variable.text != null) {
      return SelectableText.rich(
        TextSpan(
          children: processAnsiTerminalCodes(
            variable.text,
            theme.subtleFixedFontStyle,
          ),
        ),
        onTap: onTap,
      );
    }

    final hasName = variable.name?.isNotEmpty ?? false;
    return Row(
      children: [
        SelectableText.rich(
          TextSpan(
            text: hasName ? variable.name : null,
            style: variable.artificialName
                ? theme.subtleFixedFontStyle
                : theme.fixedFontStyle.apply(
                    color: theme.colorScheme.controlFlowSyntaxColor,
                  ),
            children: [
              if (hasName)
                TextSpan(
                  text: ': ',
                  style: theme.fixedFontStyle,
                ),
              if (variable.ref!.value is Sentinel)
                TextSpan(
                  text: 'Sentinel ${variable.displayValue.toString()}',
                  style: theme.subtleFixedFontStyle,
                ),
            ],
          ),
          onTap: onTap,
        ),
        if (variable.ref!.value is! Sentinel && variable.ref!.value is ObjRef?)
          VmServiceObjectLink(
            object: variable.ref!.value as ObjRef?,
            textBuilder: (object) {
              if (object is InstanceRef &&
                  object.kind == InstanceKind.kString) {
                return "'${object.valueAsString}'";
              }
              return null;
            },
            onTap: controller.findAndSelectNodeForObject,
          )
        else
          Text(
            variable.ref!.value.toString(),
            style: Theme.of(context).subtleFixedFontStyle,
          ),
      ],
    );
  }
}

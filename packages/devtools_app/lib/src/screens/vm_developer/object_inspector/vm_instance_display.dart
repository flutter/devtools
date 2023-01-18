// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/console/widgets/expandable_variable.dart';
import '../../../shared/globals.dart';
import '../../../shared/object_tree.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/split.dart';
import '../../../shared/theme.dart';
import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

class VmInstanceDisplay extends StatefulWidget {
  const VmInstanceDisplay({
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

  void _populate() async {
    final isolateRef = serviceManager.isolateManager.selectedIsolate.value;
    _root = DartObjectNode.fromValue(
      name: 'value',
      value: widget.instance.obj,
      isolateRef: isolateRef,
      artificialName: true,
    );

    _initialized = buildVariablesTree(_root)
        .then(
          (_) => _root.expand(),
        )
        .then(
          (_) => Future.wait([
            for (final child in _root.children) buildVariablesTree(child),
          ]),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Split(
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
                needsTopBorder: false,
              ),
              Flexible(
                child: FutureBuilder(
                  future: _initialized,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done)
                      return const CenteredCircularProgressIndicator();
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
        serviceObjectLinkBuilderMapEntry<ClassRef>(
          controller: controller,
          key: 'Object Class',
          object: instance.obj.classRef!,
        ),
        selectableTextBuilderMapEntry(
          'Shallow Size',
          prettyPrintBytes(
            instance.obj.size ?? 0,
            includeUnit: true,
            kbFractionDigits: 1,
            maxBytes: 512,
          ),
        ),
        MapEntry(
          'Reachable Size',
          (context) => RequestableSizeWidget(
            fetching: instance.fetchingReachableSize,
            sizeProvider: () => instance.reachableSize,
            requestFunction: instance.requestReachableSize,
          ),
        ),
        MapEntry(
          'Retained Size',
          (context) => RequestableSizeWidget(
            fetching: instance.fetchingRetainedSize,
            sizeProvider: () => instance.retainedSize,
            requestFunction: instance.requestRetainedSize,
          ),
        ),
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

    // TODO(devoncarew): Here, we want to wait until the tooltip wants to show,
    // then call toString() on variable and render the result in a tooltip. We
    // should also include the type of the value in the tooltip if the variable
    // is not null.
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
        if (variable.ref!.value is! Sentinel)
          VmServiceObjectLink(
            object: variable.ref!.value,
            textBuilder: (object) {
              if (object is InstanceRef &&
                  object.kind == InstanceKind.kString) {
                return "'${object.valueAsString}'";
              }
              return null;
            },
            onTap: (object) async {
              if (object is ObjRef) {
                await controller.findAndSelectNodeForObject(object);
              }
            },
          )
      ],
    );
  }
}

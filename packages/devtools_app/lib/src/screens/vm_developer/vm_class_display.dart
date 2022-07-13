// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to class objects in the Dart VM.
class VmClassDisplay extends StatelessWidget {
  VmClassDisplay({
    required this.clazz,
  });

  final ClassObject clazz;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Flexible(
                child: ClassInfoWidget(
                  clazz: clazz,
                ),
              ),
              Flexible(
                child: ListView(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: clazz.fetchingRetainingPath,
                      builder: (context, fetching, child) {
                        return VmExpansionTile(
                          title: 'Retaining Path',
                          onExpanded: _onExpandRetainingPath,
                          children: clazz.retainingPath == null
                              ? <Widget>[]
                              : retainingPathList(
                                  context,
                                  clazz.retainingPath!,
                                ),
                        );
                      },
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: clazz.fetchingInboundRefs,
                      builder: (context, fetching, child) {
                        return VmExpansionTile(
                          title: 'InboundReferences',
                          onExpanded: _onExpandInboundRefs,
                          children: clazz.inboundReferences == null
                              ? <Widget>[]
                              : inboundReferencesList(
                                  context,
                                  clazz.inboundReferences!,
                                ),
                        );
                      },
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ClassInstancesWidget(
            instances: clazz.instances,
          ),
        )
      ],
    );
  }

  void _onExpandRetainingPath(bool expanded) {
    if (clazz.retainingPath == null) clazz.requestRetainingPath();
  }

  void _onExpandInboundRefs(bool expanded) {
    if (clazz.inboundReferences == null) clazz.requestInboundsRefs();
  }
}

/// Displays general VM information of the Class Object.
class ClassInfoWidget extends StatelessWidget {
  const ClassInfoWidget({
    required this.clazz,
  });

  final ClassObject clazz;

  @override
  Widget build(BuildContext context) {
    return VMInfoCard(
      title: 'General Information',
      rowKeyValues: [
        MapEntry('Object Class', clazz.obj.type),
        MapEntry(
          'Shallow Size',
          prettyPrintBytes(
            clazz.obj.size ?? 0,
            includeUnit: true,
            kbFractionDigits: 1,
            maxBytes: 512,
          ),
        ),
        MapEntry(
          'Reachable Size',
          ValueListenableBuilder<bool>(
            valueListenable: clazz.fetchingReachableSize,
            builder: (context, fetching, child) => _reachableSize(fetching),
          ),
        ),
        MapEntry(
          'Retained Size',
          ValueListenableBuilder<bool>(
            valueListenable: clazz.fetchingRetainedSize,
            builder: (context, fetching, child) => _retainedSize(fetching),
          ),
        ),
        // MapEntry(
        //   'Retaining path',
        //   RequestDataButton(onPressed: _retainingPath),
        // ),
        // MapEntry('Inbound references', clazz.inboundReferences.toString()),
        MapEntry(
          'Library',
          clazz.obj.library?.name?.isEmpty ?? false
              ? clazz.script?.uri
              : clazz.obj.library?.name,
        ),
        MapEntry(
          'Script',
          '${_fileName(clazz.script?.uri) ?? ''}:${clazz.pos?.toString() ?? ''}',
        ),
        MapEntry('Superclass', clazz.obj.superClass?.name),
        MapEntry('SuperType', clazz.obj.superType?.name),
      ],
    );
  }

  String? _fileName(String? uri) {
    if (uri == null) return null;
    final splitted = uri.split('/');
    return splitted[splitted.length - 1];
  }

  Widget _reachableSize(bool fetchingReachableSize) {
    if (fetchingReachableSize) return const CircularProgressIndicator();
    if (clazz.reachableSize == null)
      return RequestDataButton(onPressed: clazz.requestReachableSize);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          clazz.reachableSize!.valueAsString == null
              ? '--'
              : prettyPrintBytes(
                  int.parse(clazz.reachableSize!.valueAsString!),
                  includeUnit: true,
                  kbFractionDigits: 1,
                  maxBytes: 512,
                )!,
        ),
        ToolbarRefresh(onPressed: clazz.requestReachableSize),
      ],
    );
  }

  Widget _retainedSize(bool fetchingRetainedSize) {
    if (fetchingRetainedSize) return const CircularProgressIndicator();
    if (clazz.retainedSize == null)
      return RequestDataButton(onPressed: clazz.requestRetainedSize);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          clazz.retainedSize!.valueAsString == null
              ? '--'
              : prettyPrintBytes(
                  int.parse(clazz.retainedSize!.valueAsString!),
                  includeUnit: true,
                  kbFractionDigits: 1,
                  maxBytes: 512,
                )!,
        ),
        ToolbarRefresh(onPressed: clazz.requestRetainedSize),
      ],
    );
  }
}

/// Displays information on the instances of the Class object.
class ClassInstancesWidget extends StatelessWidget {
  const ClassInstancesWidget({
    required this.instances,
  });

  final InstanceSet? instances;

  @override
  Widget build(BuildContext context) {
    return VMInfoCard(
      title: 'Class Instances',
      rowKeyValues: [
        MapEntry('Currently allocated', instances?.totalCount),
        const MapEntry('Strongly reachable', 'TO-DO'),
        const MapEntry('All direct instances', 'TO-DO'),
        const MapEntry('All instances of subclasses', 'TO-DO'),
        const MapEntry('All instances of implementors', 'TO-DO'),
        const MapEntry('Reachable size', 'TO-DO'),
        const MapEntry('Retained size', 'TO-DO'),
      ],
    );
  }
}

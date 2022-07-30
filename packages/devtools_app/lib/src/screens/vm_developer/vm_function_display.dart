// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/table.dart';
import '../../shared/theme.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_object_model.dart';
import 'vm_service_private_extensions.dart';

// TODO(mtaylee): Finish implementation of [ICDataArrayWidget] and add it to
// the [VmFuncDisplay] build method.

/// A widget for the object inspector historyViewport displaying information
/// related to 'Func' (function) objects in the Dart VM.
class VmFuncDisplay extends StatelessWidget {
  const VmFuncDisplay({
    required this.function,
  });

  final FuncObject function;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: FuncInfoWidget(
                        fieldDataRows: _functionDataRows(function),
                      ),
                    ),
                    Flexible(
                      child: FuncDetailsWidget(
                        detailRows: _functionDetailRows(function),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  children: [
                    RetainingPathWidget(
                      retainingPath: function.retainingPath,
                      onExpanded: _onExpandRetainingPath,
                    ),
                    InboundReferencesWidget(
                      inboundReferences: function.inboundReferences,
                      onExpanded: _onExpandInboundRefs,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onExpandRetainingPath(bool expanded) {
    if (function.retainingPath.value == null) function.requestRetainingPath();
  }

  void _onExpandInboundRefs(bool expanded) {
    if (function.inboundReferences.value == null)
      function.requestInboundsRefs();
  }
}

/// Displays general VM information of the Function Object.
class FuncInfoWidget extends StatelessWidget implements PreferredSizeWidget {
  const FuncInfoWidget({
    required this.fieldDataRows,
  });

  final List<MapEntry<String, Object?>> fieldDataRows;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: preferredSize,
      child: VMInfoCard(
        title: 'General Information',
        rowKeyValues: fieldDataRows,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        areaPaneHeaderHeight +
            fieldDataRows.length * defaultRowHeight +
            defaultSpacing,
      );
}

/// Displays detailed information of the VM Function Object.
class FuncDetailsWidget extends StatelessWidget implements PreferredSizeWidget {
  const FuncDetailsWidget({
    required this.detailRows,
  });

  final List<MapEntry<String, Object?>> detailRows;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: preferredSize,
      child: VMInfoCard(
        title: 'Function Details',
        rowKeyValues: detailRows,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        areaPaneHeaderHeight +
            detailRows.length * defaultRowHeight +
            defaultSpacing,
      );
}

/// Returns a list of key-value pairs (map entries)
/// containing the general information related to a VM Func object [function].
List<MapEntry<String, Object?>> _functionDataRows(FuncObject function) {
  String functionOwner(ObjRef? owner) {
    if (owner is LibraryRef) {
      return owner.name ?? owner.uri ?? 'Unknown Library';
    } else {
      return qualifiedName(owner) ?? function.script?.uri ?? 'Unknown';
    }
  }

  return [
    MapEntry('Object Class', function.obj.type),
    MapEntry(
      'Shallow Size',
      prettyPrintBytes(
        function.obj.size ?? 0,
        includeUnit: true,
        kbFractionDigits: 1,
        maxBytes: 512,
      ),
    ),
    MapEntry(
      'Reachable Size',
      ValueListenableBuilder<bool>(
        valueListenable: function.fetchingReachableSize,
        builder: (context, fetching, _) => fetching
            ? const CircularProgressIndicator()
            : RequestableSizeWidget(
                requestedSize: function.reachableSize,
                requestFunction: function.requestReachableSize,
              ),
      ),
    ),
    MapEntry(
      'Retained Size',
      ValueListenableBuilder<bool>(
        valueListenable: function.fetchingRetainedSize,
        builder: (context, fetching, _) => fetching
            ? const CircularProgressIndicator()
            : RequestableSizeWidget(
                requestedSize: function.retainedSize,
                requestFunction: function.requestRetainedSize,
              ),
      ),
    ),
    MapEntry(
      'Owner',
      functionOwner(function.obj.owner),
    ),
    MapEntry(
      'Script',
      '${fileNameFromUri(function.script?.uri) ?? ''}:${function.pos?.toString() ?? ''}',
    ),
  ];
}

/// Returns a list of key-value pairs (map entries)
/// containing detailed information of a VM Func object [function]..
List<MapEntry<String, Object?>> _functionDetailRows(FuncObject function) {
  String? kindDescription(String? kindValue) {
    if (kindValue == null) return null;

    if (!FunctionPrivateViewExtension.recognizedFunctionKinds
        .contains(kindValue)) {
      return 'Unrecognized function kind: $kindValue';
    }

    final camelCase = RegExp(r'(?<=[a-z])[A-Z]');

    final kind = StringBuffer();

    if (function.obj.isStatic == true) {
      kind.write('static ');
    }
    if (function.obj.isConst == true) {
      kind.write('const ');
    }

    kind.write(
      kindValue
          .replaceAllMapped(
            camelCase,
            (Match m) => ' ${m.group(0)!}',
          )
          .toLowerCase(),
    );

    return kind.toString();
  }

  String? boolYesOrNo(bool? condition) {
    if (condition == true) return 'Yes';
    if (condition == false) return 'No';
    return null;
  }

  return [
    MapEntry('Kind', kindDescription(function.kind)),
    MapEntry('Deoptimizations', function.deoptimizations?.toString()),
    MapEntry('Optimizable', boolYesOrNo(function.isOptimizable)),
    MapEntry('Inlinable', boolYesOrNo(function.isInlinable)),
    MapEntry('Intrinsic', boolYesOrNo(function.hasIntrinsic)),
    MapEntry('Recognized', boolYesOrNo(function.isRecognized)),
    MapEntry('Native', boolYesOrNo(function.isNative)),
    MapEntry('VM Name', function.vmName),
  ];
}

// TODO(mtaylee): Finish widget implementation.
/// An expansion tile showing the elements inside a function's IC data array.
class ICDataArrayWidget extends StatelessWidget {
  const ICDataArrayWidget({required this.icDataArray});

  final Instance icDataArray;

  @override
  Widget build(BuildContext context) {
    return VmExpansionTile(
      title: icDataArray.name ?? 'Instance of ${icDataArray.classRef?.name}',
      children: const [],
    );
  }
}

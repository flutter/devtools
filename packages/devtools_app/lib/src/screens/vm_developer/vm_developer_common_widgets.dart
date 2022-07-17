// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/table.dart';
import '../../shared/theme.dart';

/// A convenience widget used to create non-scrollable information cards.
///
/// `title` is displayed as the header of the card and is required.
///
/// `rowKeyValues` takes a list of key-value pairs that are to be displayed as
/// individual rows. These rows will have an alternating background color.
///
/// `table` is a widget (typically a table) that is to be displayed after the
/// rows specified for `rowKeyValues`.
class VMInfoCard extends StatelessWidget {
  const VMInfoCard({
    required this.title,
    this.rowKeyValues,
    this.table,
  });

  final String title;
  final List<MapEntry>? rowKeyValues;
  final Widget? table;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: VMInfoList(
        title: title,
        rowKeyValues: rowKeyValues,
        table: table,
      ),
    );
  }
}

class VMInfoList extends StatelessWidget {
  const VMInfoList({
    required this.title,
    this.rowKeyValues,
    this.table,
  });

  final String title;
  final List<MapEntry>? rowKeyValues;
  final Widget? table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Create shadow variables locally to avoid extra null checks.
    final rowKeyValues = this.rowKeyValues;
    final table = this.table;
    final listScrollController = ScrollController();
    return Column(
      children: [
        AreaPaneHeader(
          title: Text(title),
          needsTopBorder: false,
        ),
        if (rowKeyValues != null)
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              controller: listScrollController,
              child: ListView(
                controller: listScrollController,
                children: _prettyRows(
                  context,
                  [
                    for (final row in rowKeyValues)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            '${row.key.toString()}:',
                            style: theme.fixedFontStyle,
                          ),
                          const SizedBox(width: denseSpacing),
                          Flexible(
                            child: row.value is Widget
                                ? row.value
                                : SelectableText(
                                    row.value?.toString() ?? '--',
                                    style: theme.fixedFontStyle,
                                  ),
                          ),
                        ],
                      )
                  ],
                ),
              ),
            ),
          ),
        if (table != null) table,
      ],
    );
  }
}

List<Widget> _prettyRows(BuildContext context, List<Row> rows) {
  return [
    for (int i = 0; i < rows.length; ++i)
      _buildAlternatingRow(context, i, rows[i]),
  ];
}

Widget _buildAlternatingRow(BuildContext context, int index, Widget row) {
  return Container(
    color: alternatingColorForIndex(index, Theme.of(context).colorScheme),
    height: defaultRowHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: defaultSpacing,
    ),
    child: row,
  );
}

/// A Refresh ToolbarAction button.
class ToolbarRefresh extends ToolbarAction {
  const ToolbarRefresh({
    super.icon = Icons.refresh,
    required super.onPressed,
    super.tooltip = 'Refresh',
  });
}

/// An IconLabelButton with label 'Request' and a 'call made' icon.
class RequestDataButton extends IconLabelButton {
  const RequestDataButton({
    required super.onPressed,
    super.icon = Icons.call_made,
    super.label = 'Request',
    super.outlined = false,
  });
}

/// Displays a RequestDataButton if [requestedSize] is null, otherwise displays
/// the requestable size and a ToolbarRefresh button next to it,
/// to request that size again if required.
class RequestableSizeWidget extends StatelessWidget {
  const RequestableSizeWidget({
    required this.requestedSize,
    required this.requestFunction,
  });

  final InstanceRef? requestedSize;
  final void Function()? requestFunction;

  @override
  Widget build(BuildContext context) {
    if (requestedSize == null) {
      return RequestDataButton(onPressed: requestFunction);
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            requestedSize!.valueAsString == null
                ? '--'
                : prettyPrintBytes(
                    int.parse(requestedSize!.valueAsString!),
                    includeUnit: true,
                    kbFractionDigits: 1,
                    maxBytes: 512,
                  )!,
          ),
          ToolbarRefresh(onPressed: requestFunction),
        ],
      );
    }
  }
}

/// Wrapper to get the name of an ObjRef depending on its type.
String? _objectName(ObjRef? objectRef) {
  String? objectRefName;
  if (objectRef == null) return null;

  if (objectRef is ClassRef ||
      objectRef is FuncRef ||
      objectRef is FieldRef ||
      objectRef is LibraryRef) {
    objectRefName = (objectRef as dynamic).name;
  }

  return objectRefName;
}

/// Recursively gets the full owner name of a field or function object.
String? _ownerName(ObjRef? ref) {
  if (ref == null) return '';
  if (ref is FuncRef) {
    return '${_ownerName(ref.owner)}.${_objectName(ref)}';
  } else if (ref is FieldRef) {
    return '${_ownerName(ref.owner)}.${_objectName(ref)}';
  } else {
    return _objectName(ref) ?? '<unknown>';
  }
}

/// An ExpansionTile with an AreaPaneHeader as header and custom style
/// for the VM tools tab.
class VmExpansionTile extends StatelessWidget {
  const VmExpansionTile({
    required this.title,
    required this.children,
    this.onExpanded,
  });

  final String title;
  final List<Widget> children;
  final void Function(bool)? onExpanded;

  @override
  Widget build(BuildContext context) {
    final titleRow = AreaPaneHeader(
      title: Text(title),
      needsTopBorder: false,
    );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: titleRow,
        onExpansionChanged: onExpanded,
        tilePadding: const EdgeInsets.all(4.0),
        children: children,
      ),
    );
  }
}

/// An expandable list to display the retaining objects for a given RetainingPath.
class RetainingPathWidget extends StatelessWidget {
  const RetainingPathWidget({
    required this.retainingPath,
    this.onExpanded,
  });

  final ValueListenable<RetainingPath?> retainingPath;
  final void Function(bool)? onExpanded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RetainingPath?>(
      valueListenable: retainingPath,
      builder: (context, retainingPath, child) {
        return VmExpansionTile(
          title: 'Retaining Path',
          onExpanded: onExpanded,
          children: retainingPath == null
              ? [
                  SizedBox.fromSize(
                    size: const Size.fromHeight(
                      2 * (defaultIconSizeBeforeScaling + denseSpacing),
                    ),
                    child: const CenteredCircularProgressIndicator(),
                  )
                ]
              : _retainingPathList(
                  context,
                  retainingPath,
                ),
        );
      },
    );
  }

  /// Returns a list of Widgets that will be the rows in the VmExpansionTile
  /// for RetainingPathWidget.
  List<Widget> _retainingPathList(
    BuildContext context,
    RetainingPath retainingPath,
  ) {
    final emptyList = SelectableText(
      'No retaining objects',
      style: Theme.of(context).fixedFontStyle,
    );
    if (retainingPath.elements == null) return [emptyList];

    final firstRetainingObject = retainingPath.elements!.isNotEmpty
        ? SelectableText(
            _objectName(retainingPath.elements!.first.value) ??
                '<RetainingObject>',
            style: Theme.of(context).fixedFontStyle,
          )
        : emptyList;

    final retainingObjects = [
      Row(children: [firstRetainingObject]),
      if (retainingPath.elements!.length > 1)
        for (RetainingObject object in retainingPath.elements!.sublist(1))
          Row(
            children: [
              SelectableText(
                _retainingObjectDescription(object),
                style: Theme.of(context).fixedFontStyle,
              ),
            ],
          ),
      Row(
        children: [
          SelectableText(
            'Retained by a GC root of type ${retainingPath.gcRootType ?? '<unknown>'}',
            style: Theme.of(context).fixedFontStyle,
          ),
        ],
      )
    ];

    final retainingObjectsRows = _prettyRows(context, retainingObjects);

    return <Widget>[...retainingObjectsRows];
  }

  /// Describes the given RetainingObject [object] and its parentListIndex,
  /// parentMapKey, and parentField where applicable.
  String _retainingObjectDescription(RetainingObject object) {
    if (object.parentListIndex != null) {
      final ref = object.value as InstanceRef;
      return 'Retained by element [${object.parentListIndex}] of ${ref.classRef?.name ?? '<parentListName>'}';
    }

    if (object.parentMapKey != null) {
      final ref = object.value as InstanceRef;
      return 'Retained by element [${object.parentMapKey}] of ${ref.classRef?.name ?? '<parentMapName>'}';
    }

    String description = 'Retained by';

    if (object.parentField != null) {
      description += ' ${object.parentField} of ';
    }

    if (object.value is FieldRef) {
      final ref = object.value as FieldRef;
      description +=
          ' ${ref.declaredType?.name ?? 'Field'} ${ref.name} of ${_ownerName(ref.owner) ?? '<Owner>'}';
    } else if (object.value is FuncRef) {
      final ref = object.value as FuncRef;
      description += ' ${_ownerName(ref.owner) ?? '<Owner>'}.${ref.name}';
    } else {
      description += ' ${_objectName(object.value)}';
    }

    return description;
  }
}

/// An expandable list to display the inbound references for a given
/// instance of InboundReferences.
class InboundReferencesWidget extends StatelessWidget {
  const InboundReferencesWidget({
    required this.inboundReferences,
    this.onExpanded,
  });

  final ValueListenable<InboundReferences?> inboundReferences;
  final void Function(bool)? onExpanded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InboundReferences?>(
      valueListenable: inboundReferences,
      builder: (context, inboundReferences, child) {
        return VmExpansionTile(
          title: 'Inbound References',
          onExpanded: onExpanded,
          children: inboundReferences == null
              ? [
                  SizedBox.fromSize(
                    size: const Size.fromHeight(
                      2 * (defaultIconSizeBeforeScaling + denseSpacing),
                    ),
                    child: const CenteredCircularProgressIndicator(),
                  )
                ]
              : inboundReferencesList(
                  context,
                  inboundReferences,
                ),
        );
      },
    );
  }

  /// Returns a list of Widgets that will be the rows in the VmExpansionTile
  /// for InboundReferencesWidget.
  List<Widget> inboundReferencesList(
    BuildContext context,
    InboundReferences inboundRefs,
  ) {
    int count = 0;

    final references = <Row>[];

    for (final inboundRef in inboundRefs.references!) {
      final int? parentWordOffset =
          inboundRefs.json!['references'][count]['_parentWordOffset'];

      references.add(
        Row(
          children: [
            Flexible(
              child: SelectableText(
                _inboundRefDescription(inboundRef, parentWordOffset),
                style: Theme.of(context).fixedFontStyle,
              ),
            )
          ],
        ),
      );

      count++;
    }

    final inboundReferenceRows = _prettyRows(context, references);

    return <Widget>[...inboundReferenceRows];
  }

  /// Describes the given InboundReference [inboundRef] and its parentListIndex,
  /// [offset], and parentField where applicable.
  String _inboundRefDescription(InboundReference inboundRef, int? offset) {
    if (inboundRef.parentListIndex != null) {
      final ref = inboundRef.source as InstanceRef;
      return 'Referenced by element [${inboundRef.parentListIndex}] of ${ref.classRef?.name ?? '<parentListName>'}';
    }
    String description = 'Referenced by';

    if (offset != null) {
      description += ' offset $offset of';
    }

    if (inboundRef.parentField != null) {
      description += ' ${inboundRef.parentField} of';
    }

    if (inboundRef.source is FieldRef) {
      final ref = inboundRef.source as FieldRef;
      description +=
          ' ${ref.declaredType?.name ?? 'Field'} ${ref.name} of ${_ownerName(ref.owner) ?? '<Owner>'}';
    } else if (inboundRef.source is FuncRef) {
      final ref = inboundRef.source as FuncRef;
      description += ' ${_ownerName(ref.owner) ?? '<Owner>'}.${ref.name}';
    } else {
      description += ' ${_objectName(inboundRef.source!)}';
    }

    return description;
  }
}

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
import 'vm_service_private_extensions.dart';

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
  final void Function() requestFunction;

  @override
  Widget build(BuildContext context) {
    final size = requestedSize;
    if (size == null) {
      return RequestDataButton(onPressed: requestFunction);
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            size.valueAsString == null
                ? '--'
                : prettyPrintBytes(
                    int.parse(size.valueAsString!),
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

  if (objectRef is ClassRef || objectRef is FuncRef || objectRef is FieldRef) {
    objectRefName = (objectRef as dynamic).name;
  } else if (objectRef is LibraryRef) {
    objectRefName =
        (objectRef.name?.isEmpty ?? false) ? objectRef.uri : objectRef.name;
  } else if (objectRef is ScriptRef) {
    objectRefName = fileNameFromUri(objectRef.uri);
  } else if (objectRef is InstanceRef) {
    objectRefName = objectRef.name ??
        'Instance of ${objectRef.classRef?.name ?? '<Class>'}';
  } else {
    objectRefName = objectRef?.vmType;
  }

  return objectRefName;
}

/// Returns the name of a function, qualified with the name of
/// its owner added as a prefix, separated by a period.
///
/// For example: for function build with owner class Foo,
/// the qualified name would be Foo.build.
/// If the owner of a function is another function, qualifiedName will
/// recursively call itself until it reaches the owner class.
/// If the owner is a library instead, the library name will not be
/// included in the qualified name.
String? qualifiedName(ObjRef? ref) {
  if (ref == null) return null;

  if (ref is ClassRef) {
    return '${ref.name}';
  } else if (ref is FuncRef) {
    if (ref.owner is! LibraryRef) {
      return '${qualifiedName(ref.owner)}.${ref.name}';
    } else {
      return '${ref.name}';
    }
  }

  throw Exception('Unexpected owner type: ${ref.type}');
}

// Returns a description of the object containing its name and owner.
String? _objectDescription(ObjRef? object) {
  if (object == null) {
    return null;
  } else if (object is FieldRef) {
    return '${object.declaredType?.name ?? 'Field'} ${object.name} of ${_objectName(object.owner) ?? '<Owner>'}';
  } else if (object is FuncRef) {
    return '${qualifiedName(object) ?? '<Function Name>'}';
  } else {
    return '${_objectName(object)}';
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
    return Card(
      child: ListTileTheme(
        data: ListTileTheme.of(context).copyWith(dense: true),
        child: ExpansionTile(
          title: titleRow,
          onExpansionChanged: onExpanded,
          tilePadding: const EdgeInsets.only(
            left: densePadding,
            right: defaultSpacing,
          ),
          children: children,
        ),
      ),
    );
  }
}

class SizedCircularProgressIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: const Size.fromHeight(
        2 * (defaultIconSizeBeforeScaling + denseSpacing),
      ),
      child: const CenteredCircularProgressIndicator(),
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
      builder: (context, retainingPath, _) {
        final retainingObjects = retainingPath == null
            ? const <Widget>[]
            : _retainingPathList(
                context,
                retainingPath,
              );
        return VmExpansionTile(
          title: 'Retaining Path',
          onExpanded: onExpanded,
          children: [
            retainingPath == null
                ? SizedCircularProgressIndicator()
                : SizedBox.fromSize(
                    size: Size.fromHeight(
                      retainingObjects.length * defaultRowHeight + densePadding,
                    ),
                    child: Column(children: retainingObjects),
                  ),
          ],
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
      Row(
        children: [
          firstRetainingObject,
        ],
      ),
      if (retainingPath.elements!.length > 1)
        for (RetainingObject object in retainingPath.elements!.sublist(1))
          Row(
            children: [
              Flexible(
                child: SelectableText(
                  _retainingObjectDescription(object),
                  style: Theme.of(context).fixedFontStyle,
                ),
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

    return _prettyRows(context, retainingObjects);
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
      return 'Retained by element at [${_objectName(object.parentMapKey)}] of ${ref.classRef?.name ?? '<parentMapName>'}';
    }

    final description = StringBuffer('Retained by ');

    if (object.parentField != null) {
      description.write('${object.parentField} of ');
    }

    description.write(
      _objectDescription(object.value) ?? '<object>',
    );

    return description.toString();
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
      builder: (context, inboundReferences, _) {
        final references = inboundReferences == null
            ? const <Widget>[]
            : _inboundReferencesList(context, inboundReferences);

        return VmExpansionTile(
          title: 'Inbound References',
          onExpanded: onExpanded,
          children: [
            inboundReferences == null
                ? SizedCircularProgressIndicator()
                : SizedBox.fromSize(
                    size: Size.fromHeight(
                      references.length * defaultRowHeight + densePadding,
                    ),
                    child: Column(children: references),
                  ),
          ],
        );
      },
    );
  }

  /// Returns a list of Widgets that will be the rows in the VmExpansionTile
  /// for InboundReferencesWidget.
  List<Widget> _inboundReferencesList(
    BuildContext context,
    InboundReferences inboundRefs,
  ) {
    int index = 0;

    final references = <Row>[];

    for (final inboundRef in inboundRefs.references!) {
      final int? parentWordOffset = inboundRefs.parentWordOffset(index);

      references.add(
        Row(
          children: [
            Flexible(
              child: SelectableText(
                _inboundRefDescription(inboundRef, parentWordOffset),
                style: Theme.of(context).fixedFontStyle,
              ),
            ),
          ],
        ),
      );

      index++;
    }

    return _prettyRows(context, references);
  }

  /// Describes the given InboundReference [inboundRef] and its parentListIndex,
  /// [offset], and parentField where applicable.
  String _inboundRefDescription(InboundReference inboundRef, int? offset) {
    if (inboundRef.parentListIndex != null) {
      final ref = inboundRef.source as InstanceRef;
      return 'Referenced by element [${inboundRef.parentListIndex}] of ${ref.classRef?.name ?? '<parentListName>'}';
    }

    final description = StringBuffer('Referenced by ');

    if (offset != null) {
      description.write(
        'offset $offset of ',
      );
    }

    if (inboundRef.parentField != null) {
      description.write(
        '${_objectName(inboundRef.parentField)} of ',
      );
    }

    description.write(
      _objectDescription(inboundRef.source) ?? '<object>',
    );

    return description.toString();
  }
}

String? fileNameFromUri(String? uri) {
  if (uri == null) return null;
  final splitted = uri.split('/');
  return splitted[splitted.length - 1];
}

// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/split.dart';
import '../../shared/table.dart';
import '../../shared/theme.dart';
import '../debugger/codeview.dart';
import '../debugger/codeview_controller.dart';
import '../debugger/debugger_model.dart';
import 'object_inspector/object_inspector_view_controller.dart';
import 'object_inspector/vm_object_model.dart';
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
class VMInfoCard extends StatelessWidget implements PreferredSizeWidget {
  const VMInfoCard({
    required this.title,
    this.rowKeyValues,
    this.table,
  });

  final String title;
  final List<MapEntry<String, WidgetBuilder>>? rowKeyValues;
  final Widget? table;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: preferredSize,
      child: Card(
        child: VMInfoList(
          title: title,
          rowKeyValues: rowKeyValues,
          table: table,
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    if (table != null) {
      return Size.infinite;
    }
    return Size.fromHeight(
      areaPaneHeaderHeight +
          (rowKeyValues?.length ?? 0) * defaultRowHeight +
          defaultSpacing,
    );
  }
}

MapEntry<String, WidgetBuilder> selectableTextBuilderMapEntry(
  String key,
  String? value,
) {
  return MapEntry(
    key,
    (context) => SelectableText(
      value ?? '--',
      style: Theme.of(context).fixedFontStyle,
    ),
  );
}

MapEntry<String, WidgetBuilder>
    serviceObjectLinkBuilderMapEntry<T extends ObjRef>({
  required ObjectInspectorViewController controller,
  required String key,
  required T object,
  bool preferUri = false,
  String Function(T)? textBuilder,
}) {
  return MapEntry(
    key,
    (context) => VmServiceObjectLink<T>(
      object: object,
      textBuilder: textBuilder,
      preferUri: preferUri,
      onTap: (object) async {
        await controller.findAndSelectNodeForObject(object);
      },
    ),
  );
}

class VMInfoList extends StatelessWidget {
  const VMInfoList({
    required this.title,
    this.rowKeyValues,
    this.table,
  });

  final String title;
  final List<MapEntry<String, WidgetBuilder>>? rowKeyValues;
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
                children: prettyRows(
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
                            child: Builder(builder: row.value),
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

List<Widget> prettyRows(BuildContext context, List<Row> rows) {
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

/// Displays a RequestDataButton if the data provided by [sizeProvider] is null,
/// otherwise displays the size data and a ToolbarRefresh button next
/// to it, to request that data again if required.
///
/// When the data is being requested (the value of [fetching] is true),
/// a CircularProgressIndicator will be displayed.
class RequestableSizeWidget extends StatelessWidget {
  const RequestableSizeWidget({
    required this.fetching,
    required this.sizeProvider,
    required this.requestFunction,
  });

  final ValueListenable<bool> fetching;
  final InstanceRef? Function() sizeProvider;
  final void Function() requestFunction;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: fetching,
      builder: (context, fetching, _) {
        if (fetching) {
          return const AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: EdgeInsets.all(densePadding),
              child: CircularProgressIndicator(),
            ),
          );
        } else {
          final size = sizeProvider();
          return size == null
              ? RequestDataButton(onPressed: requestFunction)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SelectableText(
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
      },
    );
  }
}

/// Wrapper to get the name of an ObjRef depending on its type.
String? _objectName(ObjRef? objectRef) {
  if (objectRef == null) {
    return null;
  }

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
    objectRefName = objectRef.vmType ?? objectRef.type;

    if (objectRefName.startsWith('@')) {
      objectRefName = objectRefName.substring(1, objectRefName.length);
    }
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
      needsBottomBorder: false,
      // We'll set the color in the Card so the InkWell shows a consistent
      // color when the user hovers over the ExpansionTile.
      backgroundColor: Colors.transparent,
    );
    final theme = Theme.of(context);
    return Card(
      color: theme.titleSolidBackgroundColor,
      child: ListTileTheme(
        data: ListTileTheme.of(context).copyWith(
          dense: true,
        ),
        child: Theme(
          // Prevents divider lines appearing at the top and bottom of the
          // expanded ExpansionTile.
          data: theme.copyWith(dividerColor: Colors.transparent),
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

    return prettyRows(context, retainingObjects);
  }

  /// Describes the given RetainingObject [object] and its parentListIndex,
  /// parentMapKey, and parentField where applicable.
  String _retainingObjectDescription(RetainingObject object) {
    final parentListIndex = object.parentListIndex;
    if (parentListIndex != null) {
      return 'Retained by ${_parentListElementDescription(
        parentListIndex,
        object.value,
      )}';
    }

    if (object.parentMapKey != null) {
      final ref = object.value;
      final parentMapKey = _objectName(object.parentMapKey);

      final parentMapName = _instanceClassName(ref) ?? '<parentMapName>';

      return 'Retained by element at [$parentMapKey] of $parentMapName';
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

String? _instanceClassName(ObjRef? object) {
  if (object == null) {
    return null;
  }

  return object is InstanceRef ? object.classRef?.name : _objectName(object);
}

String _parentListElementDescription(int listIndex, ObjRef? obj) {
  final parentListName = _instanceClassName(obj) ?? '<parentListName>';
  return 'element [$listIndex] of $parentListName';
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

    return prettyRows(context, references);
  }

  /// Describes the given InboundReference [inboundRef] and its parentListIndex,
  /// [offset], and parentField where applicable.
  String _inboundRefDescription(InboundReference inboundRef, int? offset) {
    final parentListIndex = inboundRef.parentListIndex;
    if (parentListIndex != null) {
      return 'Referenced by ${_parentListElementDescription(
        parentListIndex,
        inboundRef.source,
      )}';
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

class VmServiceObjectLink<T> extends StatelessWidget {
  const VmServiceObjectLink({
    required this.object,
    required this.onTap,
    this.preferUri = false,
    this.textBuilder,
  });

  final T object;
  final bool preferUri;
  final String Function(T)? textBuilder;
  final FutureOr<void> Function(T) onTap;

  @override
  Widget build(BuildContext context) {
    String text = '';
    if (textBuilder == null) {
      if (object is LibraryRef) {
        final lib = object as LibraryRef;
        if (lib.uri!.startsWith('dart') || preferUri) {
          text = lib.uri!;
        } else {
          final name = lib.name;
          text = name!.isEmpty ? lib.uri! : name;
        }
      } else if (object is FieldRef) {
        final field = object as FieldRef;
        text = field.name!;
      } else if (object is FuncRef) {
        final func = object as FuncRef;
        text = func.name!;
      } else if (object is ScriptRef) {
        final script = object as ScriptRef;
        text = script.uri!;
      } else if (object is ClassRef) {
        final cls = object as ClassRef;
        text = cls.name!;
      } else if (object is CodeRef) {
        final code = object as CodeRef;
        text = code.name!;
      } else if (object is InstanceRef) {
        final instance = object as InstanceRef;
        if (instance.kind == InstanceKind.kTypeParameter) {
          final buf = StringBuffer();
          final typeParams = instance.typeParameters!;
          buf.write('<');
          for (int i = 0; i < typeParams.length; ++i) {
            buf.write(typeParams[i].valueAsString);
            if (i + 1 != typeParams.length) {
              buf.write(', ');
            }
          }
          buf.write('>');
          text = buf.toString();
        } else if (instance.kind == InstanceKind.kList) {
          text = 'List(length: ${instance.length})';
        } else if (instance.kind == InstanceKind.kType) {
          text = instance.name!;
        } else {
          if (instance.valueAsString != null) {
            text = instance.valueAsString!;
          } else {
            final cls = instance.classRef!;
            text = 'Instance of ${cls.name}';
          }
        }
      } else if (object is TypeArgumentsRef) {
        final typeArgs = object as TypeArgumentsRef;
        text = typeArgs.name!;
      }
    } else {
      text = textBuilder!(object);
    }

    final theme = Theme.of(context);
    return SelectableText.rich(
      style: theme.linkTextStyle.apply(
        overflow: TextOverflow.ellipsis,
      ),
      maxLines: 1,
      TextSpan(
        text: text,
        style: theme.linkTextStyle.apply(
          fontFamily: theme.fixedFontStyle.fontFamily,
          overflow: TextOverflow.ellipsis,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            await onTap(object);
          },
      ),
    );
  }
}

/// A widget for the object inspector historyViewport containing the main
/// layout of information widgets related to VM object types.
class VmObjectDisplayBasicLayout extends StatelessWidget {
  const VmObjectDisplayBasicLayout({
    required this.object,
    required this.generalDataRows,
    this.sideCardDataRows,
    this.generalInfoTitle = 'General Information',
    this.sideCardTitle = 'Object Details',
    this.expandableWidgets,
  });

  final VmObject object;
  final List<MapEntry<String, WidgetBuilder>> generalDataRows;
  final List<MapEntry<String, WidgetBuilder>>? sideCardDataRows;
  final String generalInfoTitle;
  final String sideCardTitle;
  final List<Widget>? expandableWidgets;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: VMInfoCard(
                  title: generalInfoTitle,
                  rowKeyValues: generalDataRows,
                ),
              ),
              if (sideCardDataRows != null)
                Flexible(
                  child: VMInfoCard(
                    title: sideCardTitle,
                    rowKeyValues: sideCardDataRows,
                  ),
                ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            children: [
              RetainingPathWidget(
                retainingPath: object.retainingPath,
                onExpanded: _onExpandRetainingPath,
              ),
              InboundReferencesWidget(
                inboundReferences: object.inboundReferences,
                onExpanded: _onExpandInboundRefs,
              ),
              ...?expandableWidgets,
            ],
          ),
        ),
      ],
    );
  }

  void _onExpandRetainingPath(bool expanded) {
    if (object.retainingPath.value == null) {
      object.requestRetainingPath();
    }
  }

  void _onExpandInboundRefs(bool expanded) {
    if (object.inboundReferences.value == null) {
      object.requestInboundsRefs();
    }
  }
}

List<MapEntry<String, WidgetBuilder>> vmObjectGeneralDataRows(
  ObjectInspectorViewController controller,
  VmObject object,
) {
  return [
    selectableTextBuilderMapEntry('Object Class', object.obj.type),
    selectableTextBuilderMapEntry(
      'Shallow Size',
      prettyPrintBytes(
        object.obj.size ?? 0,
        includeUnit: true,
        kbFractionDigits: 1,
        maxBytes: 512,
      ),
    ),
    MapEntry(
      'Reachable Size',
      (context) => RequestableSizeWidget(
        fetching: object.fetchingReachableSize,
        sizeProvider: () => object.reachableSize,
        requestFunction: object.requestReachableSize,
      ),
    ),
    MapEntry(
      'Retained Size',
      (context) => RequestableSizeWidget(
        fetching: object.fetchingRetainedSize,
        sizeProvider: () => object.retainedSize,
        requestFunction: object.requestRetainedSize,
      ),
    ),
    if (object is ClassObject || object is ScriptObject)
      serviceObjectLinkBuilderMapEntry<LibraryRef>(
        controller: controller,
        key: 'Library',
        object: (object.obj as dynamic).library,
      ),
    if (object is FieldObject || object is FuncObject)
      serviceObjectLinkBuilderMapEntry<ObjRef>(
        controller: controller,
        key: 'Owner',
        object: (object.obj as dynamic).owner,
      ),
    if (object is! ScriptObject && object is! LibraryObject)
      serviceObjectLinkBuilderMapEntry<ScriptRef>(
        controller: controller,
        key: 'Script',
        object: object.script!,
        textBuilder: (script) {
          return '${fileNameFromUri(script.uri) ?? ''}:${object.pos?.toString() ?? ''}';
        },
      ),
  ];
}

/// Creates a simple [CodeView] which displays the code relevant to [object] in
/// [script].
///
/// If [object] is synthetic and doesn't have actual token positions,
/// [object]'s owner's code will be displayed instead.
class ObjectInspectorCodeView extends StatefulWidget {
  ObjectInspectorCodeView({
    required this.codeViewController,
    required this.script,
    required this.object,
    required this.child,
  }) : super(key: ValueKey(object));

  final CodeViewController codeViewController;
  final ScriptRef script;
  final ObjRef object;
  final Widget child;

  @override
  State<ObjectInspectorCodeView> createState() =>
      _ObjectInspectorCodeViewState();
}

class _ObjectInspectorCodeViewState extends State<ObjectInspectorCodeView> {
  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (widget.script != widget.codeViewController.currentScriptRef.value) {
      widget.codeViewController.resetScriptLocation(
        ScriptLocation(widget.script),
      );
    }
  }

  @override
  void didUpdateWidget(ObjectInspectorCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.script != widget.codeViewController.currentScriptRef.value) {
      widget.codeViewController.resetScriptLocation(
        ScriptLocation(widget.script),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ParsedScript?>(
      valueListenable: widget.codeViewController.currentParsedScript,
      builder: (context, currentParsedScript, _) {
        LineRange? lineRange;
        if (currentParsedScript != null) {
          final obj = widget.object;
          SourceLocation? location;
          if (obj is ClassRef) {
            location = obj.location!;
          } else if (obj is FuncRef) {
            location = obj.location!;
            // If there's no line associated with the location, we're likely
            // dealing with an artificial field / method like a constructor.
            // We'll display the owner's code instead of showing nothing,
            // although showing a "No Source Available" message is another
            // option.
            final owner = obj.owner;
            if (location.line == null && obj.owner is ClassRef) {
              location = owner!.location;
            }
          } else if (obj is FieldRef) {
            location = obj.location!;
            // If there's no line associated with the location, we're likely
            // dealing with an artificial field / method like a constructor.
            // We'll display the owner's code instead of showing nothing,
            // although showing a "No Source Available" message is another
            // option.
            final owner = obj.owner;
            if (location.line == null && owner is ClassRef) {
              location = owner.location;
            }
          }

          if (location != null &&
              location.line != null &&
              location.endTokenPos != null) {
            final script = currentParsedScript.script;
            final startLine = location.line!;
            final endLine = script.getLineNumberFromTokenPos(
              location.endTokenPos!,
            )!;
            lineRange = LineRange(startLine, endLine);
          }
        }

        return Split(
          axis: Axis.vertical,
          initialFractions: const [0.5, 0.5],
          children: [
            OutlineDecoration.onlyBottom(
              child: widget.child,
            ),
            Column(
              children: [
                const AreaPaneHeader(
                  title: Text('Code Preview'),
                ),
                Expanded(
                  child: CodeView(
                    codeViewController: widget.codeViewController,
                    scriptRef: widget.script,
                    parsedScript: currentParsedScript,
                    enableFileExplorer: false,
                    enableHistory: false,
                    enableSearch: false,
                    lineRange: lineRange,
                    onSelected: breakpointManager.toggleBreakpoint,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

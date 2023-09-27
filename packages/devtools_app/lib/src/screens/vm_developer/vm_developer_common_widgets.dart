// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:vm_service/vm_service.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/tree.dart';
import '../debugger/codeview.dart';
import '../debugger/codeview_controller.dart';
import '../debugger/debugger_model.dart';
import 'object_inspector/inbound_references_tree.dart';
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
    super.key,
    required this.title,
    this.roundedTopBorder = true,
    this.rowKeyValues,
    this.table,
  });

  final String title;
  final bool roundedTopBorder;
  final List<MapEntry<String, WidgetBuilder>>? rowKeyValues;
  final Widget? table;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: preferredSize,
      child: VMInfoList(
        title: title,
        roundedTopBorder: roundedTopBorder,
        rowKeyValues: rowKeyValues,
        table: table,
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
    (context) => Text(
      value ?? '--',
      style: Theme.of(context).fixedFontStyle,
    ),
  );
}

MapEntry<String, WidgetBuilder> serviceObjectLinkBuilderMapEntry({
  required ObjectInspectorViewController controller,
  required String key,
  required Response? object,
  bool preferUri = false,
  String Function(Response?)? textBuilder,
}) {
  return MapEntry(
    key,
    (context) => VmServiceObjectLink(
      object: object,
      textBuilder: textBuilder,
      preferUri: preferUri,
      onTap: controller.findAndSelectNodeForObject,
    ),
  );
}

class VMInfoList extends StatelessWidget {
  const VMInfoList({
    super.key,
    required this.title,
    this.roundedTopBorder = true,
    this.rowKeyValues,
    this.table,
  });

  final String title;
  final bool roundedTopBorder;
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
          includeTopBorder: false,
          roundedTopBorder: roundedTopBorder,
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
                          Text(
                            '${row.key.toString()}:',
                            style: theme.fixedFontStyle,
                          ),
                          const SizedBox(width: denseSpacing),
                          Flexible(
                            child: Builder(builder: row.value),
                          ),
                        ],
                      ),
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

/// Displays a RequestDataButton if the data provided by [sizeProvider] is null,
/// otherwise displays the size data and a ToolbarRefresh button next
/// to it, to request that data again if required.
///
/// When the data is being requested (the value of [fetching] is true),
/// a CircularProgressIndicator will be displayed.
class RequestableSizeWidget extends StatelessWidget {
  const RequestableSizeWidget({
    super.key,
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
              ? GaDevToolsButton(
                  icon: Icons.call_made,
                  label: 'Request',
                  outlined: false,
                  gaScreen: gac.vmTools,
                  gaSelection: gac.requestSize,
                  onPressed: requestFunction,
                )
              : Row(
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
      },
    );
  }
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
    return ref.owner is! LibraryRef
        ? '${qualifiedName(ref.owner)}.${ref.name}'
        : '${ref.name}';
  }

  throw Exception('Unexpected owner type: ${ref.type}');
}

/// An ExpansionTile with an AreaPaneHeader as header and custom style
/// for the VM tools tab.
class VmExpansionTile extends StatelessWidget {
  const VmExpansionTile({
    super.key,
    required this.title,
    required this.children,
    this.onExpanded,
  });

  final String title;
  final List<Widget> children;
  final void Function(bool)? onExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTileTheme(
        data: ListTileTheme.of(context).copyWith(
          dense: true,
        ),
        child: Theme(
          // Prevents divider lines appearing at the top and bottom of the
          // expanded ExpansionTile.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: DefaultTextStyle(
              style: theme.textTheme.titleSmall!,
              child: Text(title),
            ),
            onExpansionChanged: onExpanded,
            tilePadding: const EdgeInsets.only(
              left: defaultSpacing,
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
  const SizedCircularProgressIndicator({super.key});

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

class ExpansionTileInstanceList extends StatelessWidget {
  const ExpansionTileInstanceList({
    super.key,
    required this.controller,
    required this.title,
    required this.elements,
  });

  final ObjectInspectorViewController controller;
  final String title;
  final List<Response?> elements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Row>[
      for (int i = 0; i < elements.length; ++i)
        Row(
          children: [
            Text(
              '[$i]: ',
              style: theme.subtleFixedFontStyle,
            ),
            VmServiceObjectLink(
              object: elements[i],
              onTap: controller.findAndSelectNodeForObject,
            ),
          ],
        ),
    ];
    return VmExpansionTile(
      title: '$title (${elements.length})',
      children: prettyRows(context, children),
    );
  }
}

/// An expandable list to display the retaining objects for a given RetainingPath.
class RetainingPathWidget extends StatelessWidget {
  const RetainingPathWidget({
    super.key,
    required this.controller,
    required this.retainingPath,
    this.onExpanded,
  });

  final ObjectInspectorViewController controller;
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
                ? const SizedCircularProgressIndicator()
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
    Future<void> onTap(ObjRef? obj) async {
      if (obj == null) return;
      await controller.findAndSelectNodeForObject(obj);
    }

    final theme = Theme.of(context);
    final emptyList = Text(
      'No retaining objects',
      style: theme.fixedFontStyle,
    );
    if (retainingPath.elements == null) return [emptyList];

    final firstRetainingObject = retainingPath.elements!.isNotEmpty
        ? VmServiceObjectLink(
            object: retainingPath.elements!.first.value,
            onTap: onTap,
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
                child: DefaultTextStyle(
                  style: theme.fixedFontStyle,
                  child: _RetainingObjectDescription(
                    object: object,
                    onTap: onTap,
                  ),
                ),
              ),
            ],
          ),
      Row(
        children: [
          Text(
            'Retained by a GC root of type: ${retainingPath.gcRootType ?? '<unknown>'}',
            style: theme.fixedFontStyle,
          ),
        ],
      ),
    ];

    return prettyRows(context, retainingObjects);
  }
}

class _RetainingObjectDescription extends StatelessWidget {
  const _RetainingObjectDescription({
    required this.object,
    required this.onTap,
  });

  final RetainingObject object;
  final Function(ObjRef? obj) onTap;

  @override
  Widget build(BuildContext context) {
    final parentListIndex = object.parentListIndex;
    if (parentListIndex != null) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: 'Retained by element [$parentListIndex] of '),
            VmServiceObjectLink(
              object: object.value,
              onTap: onTap,
            ).buildTextSpan(context),
          ],
        ),
      );
    }

    if (object.parentMapKey != null) {
      return RichText(
        text: TextSpan(
          children: [
            const TextSpan(text: 'Retained by element at ['),
            VmServiceObjectLink(object: object.parentMapKey, onTap: onTap)
                .buildTextSpan(context),
            const TextSpan(text: '] of '),
            VmServiceObjectLink(object: object.value, onTap: onTap)
                .buildTextSpan(context),
          ],
        ),
      );
    }

    final entries = <TextSpan>[
      const TextSpan(text: 'Retained by '),
    ];

    if (object.parentField is int) {
      assert((object.value as InstanceRef).kind == InstanceKind.kRecord);
      entries.add(TextSpan(text: '\$${object.parentField} of '));
    } else if (object.parentField != null) {
      entries.add(TextSpan(text: '${object.parentField} of '));
    }

    if (object.value is FieldRef) {
      final field = object.value as FieldRef;
      entries.addAll(
        [
          VmServiceObjectLink(
            object: field.declaredType,
            onTap: onTap,
          ).buildTextSpan(context),
          const TextSpan(text: ' '),
          VmServiceObjectLink(
            object: field,
            onTap: onTap,
          ).buildTextSpan(context),
          const TextSpan(text: ' of '),
          VmServiceObjectLink(
            object: field.owner,
            onTap: onTap,
          ).buildTextSpan(context),
        ],
      );
    } else if (object.value is FuncRef) {
      final func = object.value as FuncRef;
      entries.add(
        VmServiceObjectLink(
          object: func,
          onTap: onTap,
        ).buildTextSpan(context),
      );
    } else {
      entries.add(
        VmServiceObjectLink(
          object: object.value,
          onTap: onTap,
        ).buildTextSpan(context),
      );
    }
    return RichText(
      text: TextSpan(children: entries),
    );
  }
}

class InboundReferencesTree extends StatelessWidget {
  const InboundReferencesTree({
    super.key,
    required this.controller,
    required this.object,
    this.onExpanded,
  });

  final ObjectInspectorViewController controller;
  final VmObject object;
  final void Function(bool)? onExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VmExpansionTile(
      title: 'Inbound References',
      onExpanded: onExpanded,
      children: [
        const Divider(height: 1),
        Container(
          color: theme.expansionTileTheme.backgroundColor,
          child: ValueListenableBuilder(
            valueListenable: object.inboundReferencesTree,
            builder: (context, references, _) {
              return TreeView<InboundReferencesTreeNode>(
                dataRootsListenable: object.inboundReferencesTree,
                dataDisplayProvider: (node, _) => InboundReferenceWidget(
                  controller: controller,
                  node: node,
                ),
                emptyTreeViewBuilder: () {
                  return Padding(
                    padding: EdgeInsets.all(defaultRowHeight / 2),
                    child: const Text(
                      'There are no inbound references for this object',
                    ),
                  );
                },
                onItemExpanded: object.expandInboundRef,
                onItemSelected: (_) => null,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// An entry in a [InboundReferencesTree].
class InboundReferenceWidget extends StatelessWidget {
  const InboundReferenceWidget({
    super.key,
    required this.controller,
    required this.node,
  });

  final ObjectInspectorViewController controller;
  final InboundReferencesTreeNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowContent = <Widget>[
      const Text('Referenced by '),
    ];

    final parentField = node.ref.parentField;
    if (parentField != null) {
      if (parentField is int) {
        // The parent field is an entry in a list
        rowContent.add(Text('element $parentField of '));
      } else if (parentField is String) {
        rowContent.add(Text('$parentField in '));
      }
    }

    rowContent.add(
      VmServiceObjectLink(
        object: node.ref.source,
        onTap: controller.findAndSelectNodeForObject,
      ),
    );
    return DefaultTextStyle(
      style: theme.fixedFontStyle,
      child: Row(
        children: rowContent,
      ),
    );
  }
}

class VmServiceObjectLink extends StatelessWidget {
  const VmServiceObjectLink({
    super.key,
    required this.object,
    required this.onTap,
    this.preferUri = false,
    this.textBuilder,
  });

  final Response? object;
  final bool preferUri;
  final String? Function(Response?)? textBuilder;
  final FutureOr<void> Function(ObjRef) onTap;

  @visibleForTesting
  static String? defaultTextBuilder(
    Object? object, {
    bool preferUri = false,
  }) {
    if (object == null) return null;
    return switch (object) {
      FieldRef(:final name) ||
      FuncRef(:final name) ||
      CodeRef(:final name) ||
      TypeArgumentsRef(:final name) =>
        name,
      // If a class has an empty name, it's a special "top level" class.
      ClassRef(:final name) => name!.isEmpty ? 'top-level-class' : name,
      LibraryRef(:final uri, :final name) =>
        uri!.startsWith('dart') || preferUri
            ? uri
            : (name!.isEmpty ? uri : name),
      ScriptRef(:final uri) => uri,
      ContextRef(:final length) => 'Context(length: $length)',
      Sentinel(:final valueAsString) => 'Sentinel $valueAsString',
      InstanceRef() => _textForInstanceRef(object),
      ObjRef(:final isICData) when isICData =>
        'ICData(${object.asICData.selector})',
      ObjRef(:final isObjectPool) when isObjectPool =>
        'Object Pool(length: ${object.asObjectPool.length})',
      ObjRef(:final isWeakArray) when isWeakArray =>
        'WeakArray(length: ${object.asWeakArray.length})',
      ObjRef(:final vmType) => vmType,
      _ => null,
    };
  }

  static String? _textForInstanceRef(InstanceRef instance) {
    final valueAsString = instance.valueAsString;
    switch (instance.kind) {
      case InstanceKind.kList:
        return 'List(length: ${instance.length})';
      case InstanceKind.kMap:
        return 'Map(length: ${instance.length})';
      case InstanceKind.kRecord:
        return 'Record';
      case InstanceKind.kType:
      case InstanceKind.kTypeParameter:
        return instance.name;
      case InstanceKind.kStackTrace:
        final trace = stack_trace.Trace.parse(valueAsString!);
        final depth = trace.frames.length;
        return 'StackTrace ($depth ${pluralize('frame', depth)})';
      default:
        return valueAsString ?? '${instance.classRef!.name}';
    }
  }

  TextSpan buildTextSpan(BuildContext context) {
    final theme = Theme.of(context);

    String? text = textBuilder?.call(object) ??
        defaultTextBuilder(object, preferUri: preferUri);

    // Sentinels aren't objects that can be inspected.
    final isServiceObject = object is! Sentinel && text != null;
    text ??= object.toString();

    final TextStyle style;
    if (isServiceObject) {
      style = theme.fixedFontLinkStyle;
    } else {
      style = theme.fixedFontStyle;
    }
    return TextSpan(
      text: text,
      style: style.apply(overflow: TextOverflow.ellipsis),
      recognizer: isServiceObject
          ? (TapGestureRecognizer()
            ..onTap = () async {
              final obj = object;
              if (obj is ObjRef) {
                await onTap(obj);
              }
            })
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      maxLines: 1,
      text: TextSpan(
        style: theme.linkTextStyle.apply(
          fontFamily: theme.fixedFontStyle.fontFamily,
          overflow: TextOverflow.ellipsis,
        ),
        children: [buildTextSpan(context)],
      ),
    );
  }
}

/// A widget for the object inspector historyViewport containing the main
/// layout of information widgets related to VM object types.
class VmObjectDisplayBasicLayout extends StatelessWidget {
  const VmObjectDisplayBasicLayout({
    super.key,
    required this.controller,
    required this.object,
    required this.generalDataRows,
    this.sideCardDataRows,
    this.generalInfoTitle = 'General Information',
    this.sideCardTitle = 'Object Details',
    this.expandableWidgets,
  });

  final ObjectInspectorViewController controller;
  final VmObject object;
  final List<MapEntry<String, WidgetBuilder>> generalDataRows;
  final List<MapEntry<String, WidgetBuilder>>? sideCardDataRows;
  final String generalInfoTitle;
  final String sideCardTitle;
  final List<Widget>? expandableWidgets;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: OutlineDecoration(
                  showLeft: false,
                  showTop: false,
                  showRight: sideCardDataRows != null,
                  child: VMInfoCard(
                    title: generalInfoTitle,
                    rowKeyValues: generalDataRows,
                    roundedTopBorder: false,
                  ),
                ),
              ),
              if (sideCardDataRows != null)
                Flexible(
                  child: OutlineDecoration.onlyBottom(
                    child: VMInfoCard(
                      title: sideCardTitle,
                      rowKeyValues: sideCardDataRows,
                    ),
                  ),
                ),
            ],
          ),
        ),
        RetainingPathWidget(
          controller: controller,
          retainingPath: object.retainingPath,
          onExpanded: _onExpandRetainingPath,
        ),
        InboundReferencesTree(
          controller: controller,
          object: object,
          onExpanded: _onExpandInboundRefs,
        ),
        ...?expandableWidgets,
      ],
    );
  }

  void _onExpandRetainingPath(bool _) {
    if (object.retainingPath.value == null) {
      unawaited(object.requestRetainingPath());
    }
  }

  void _onExpandInboundRefs(bool _) {
    if (object.inboundReferencesTree.value.isEmpty) {
      unawaited(object.requestInboundsRefs());
    }
  }
}

MapEntry<String, WidgetBuilder> shallowSizeRowBuilder(VmObject object) {
  return selectableTextBuilderMapEntry(
    'Shallow Size',
    prettyPrintBytes(
      object.obj.size ?? 0,
      includeUnit: true,
      kbFractionDigits: 1,
      maxBytes: 512,
    ),
  );
}

MapEntry<String, WidgetBuilder> reachableSizeRowBuilder(VmObject object) {
  return MapEntry(
    'Reachable Size',
    (context) => RequestableSizeWidget(
      fetching: object.fetchingReachableSize,
      sizeProvider: () => object.reachableSize,
      requestFunction: object.requestReachableSize,
    ),
  );
}

MapEntry<String, WidgetBuilder> retainedSizeRowBuilder(VmObject object) {
  return MapEntry(
    'Retained Size',
    (context) => RequestableSizeWidget(
      fetching: object.fetchingRetainedSize,
      sizeProvider: () => object.retainedSize,
      requestFunction: object.requestRetainedSize,
    ),
  );
}

List<MapEntry<String, WidgetBuilder>> vmObjectGeneralDataRows(
  ObjectInspectorViewController controller,
  VmObject object,
) {
  return [
    selectableTextBuilderMapEntry('Object Class', object.obj.type),
    shallowSizeRowBuilder(object),
    reachableSizeRowBuilder(object),
    retainedSizeRowBuilder(object),
    if (object is ClassObject && object.obj.library != null)
      serviceObjectLinkBuilderMapEntry(
        controller: controller,
        key: 'Library',
        object: object.obj.library!,
      ),
    if (object is ScriptObject)
      serviceObjectLinkBuilderMapEntry(
        controller: controller,
        key: 'Library',
        object: object.obj.library!,
      ),
    if (object is FieldObject)
      serviceObjectLinkBuilderMapEntry(
        controller: controller,
        key: 'Owner',
        object: object.obj.owner!,
      ),
    if (object is FuncObject)
      serviceObjectLinkBuilderMapEntry(
        controller: controller,
        key: 'Owner',
        object: object.obj.owner!,
      ),
    if (object is! ScriptObject &&
        object is! LibraryObject &&
        object.script != null)
      serviceObjectLinkBuilderMapEntry(
        controller: controller,
        key: 'Script',
        object: object.script!,
        textBuilder: (s) {
          final script = s as ScriptRef;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_maybeResetScriptLocation());
  }

  @override
  void didUpdateWidget(ObjectInspectorCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_maybeResetScriptLocation());
  }

  Future<void> _maybeResetScriptLocation() async {
    if (widget.script != widget.codeViewController.currentScriptRef.value) {
      await widget.codeViewController.resetScriptLocation(
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
                  roundedTopBorder: false,
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../config_specific/host_platform/host_platform.dart';
import '../debugger/debugger_screen.dart';
import '../globals.dart';
import '../theme.dart';
import '../tree.dart';
import '../trees.dart';
import '../utils.dart';
import '../version.dart';
import 'object_tree_controller.dart';

const containerIcon = Icons.folder;
const libraryIcon = Icons.insert_chart;
const listItemHeight = 40.0;

const bool displayLibraryExplorer = true;

/// A node in a tree of VM service objects.
///
/// TODO(bkonyi): update docs.
/// A node can be one of the following:
///   - a directory (a name with potentially some child nodes)
///   - a script reference (where [scriptRef] is non-null), or a combination of both
/// (where the node has a non-null [scriptRef] but also contains child nodes).
class VMServiceObjectNode extends TreeNode<VMServiceObjectNode> {
  VMServiceObjectNode(
    this.name,
    this.object, {
    this.isSelectable = true,
  });

  final String name;
  bool isSelectable;

  ObjRef object;
  ScriptRef script;

  @override
  bool isSelected = false;

  /// This exists to allow for O(1) lookup of children when building the tree.
  final Map<String, VMServiceObjectNode> _childrenAsMap = {};

  @override
  bool get isExpandable => super.isExpandable || object is ClassRef;

  /// Given a flat list of service protocol scripts, return a tree of scripts
  /// representing the best hierarchical grouping.
  static List<VMServiceObjectNode> createRootsFrom(
    List<VMServiceLibraryContents> libs,
    Expando<bool> shouldFilterExpando,
  ) {
    // The name of this node is not exposed to users.
    final root = VMServiceObjectNode('<root>', ObjRef(id: '0'));

    for (var lib in libs) {
      if (!shouldFilterExpando[lib.lib]) {
        continue;
      }
      for (final script in lib.lib.scripts) {
        if (!shouldFilterExpando[script]) {
          continue;
        }
        _buildScriptNode(root, script, lib: lib.lib);
      }

      if (!displayLibraryExplorer) {
        for (final clazz in lib.classes) {
          if (!shouldFilterExpando[clazz]) {
            continue;
          }
          final clazzNode = _buildScriptNode(root, clazz.location.script)
              ._getCreateChild(clazz.name, clazz);
          if (clazz is Class) {
            for (final function in clazz.functions) {
              clazzNode._getCreateChild(function.name, function);
            }
            for (final field in clazz.fields) {
              clazzNode._getCreateChild(field.name, field);
            }
          }
        }

        for (final function in lib.functions) {
          if (!shouldFilterExpando[function]) {
            continue;
          }
          _buildScriptNode(root, function.location.script)
              ._getCreateChild(function.name, function);
        }

        for (final field in lib.fields) {
          if (!shouldFilterExpando[field]) {
            continue;
          }
          _buildScriptNode(root, field.location.script)
              ._getCreateChild(field.name, field);
        }
      }
    }

    // Clear out the _childrenAsMap map.
    root._trimChildrenAsMapEntries();

    // Sort each subtree to use the following ordering:
    //   - Scripts
    //   - Classes
    //   - Functions
    //   - Variables
    for (final child in root.children) {
      child._sortEntriesByType();
    }
    root.children.sort((a, b) => a.name.compareTo(b.name));

    return root.children;
  }

  static VMServiceObjectNode _buildScriptNode(
    VMServiceObjectNode node,
    ScriptRef script, {
    LibraryRef lib,
  }) {
    final parts = script.uri.split('/');
    final name = parts.removeLast();
    final dir = parts.join('/');

    if (parts.isNotEmpty) {
      //print('name: $name selectable: ${lib != null}');
      // Root nodes shouldn't be selectable unless they're a library node.
      node = node._getCreateChild(dir, null, isSelectable: false);
    }
    node = node._getCreateChild(name, script);
    if (!node.isSelectable) {
      node.isSelectable = true;
    }
    node.script = script;

    // Is this is a top-level node and a library is specified, this must be a
    // library node.
    if (parts.isEmpty && lib != null) {
      node.object = lib;
    }
    return node;
  }

  VMServiceObjectNode _getCreateChild(
    String name,
    ObjRef object, {
    bool isSelectable = true,
  }) {
    return _childrenAsMap.putIfAbsent(
      name,
      () => _createChild(name, object, isSelectable: isSelectable),
    );
  }

  VMServiceObjectNode _createChild(
    String name,
    ObjRef object, {
    bool isSelectable = true,
  }) {
    final child = VMServiceObjectNode(
      name,
      object,
      isSelectable: isSelectable,
    );
    child.parent = this;
    children.add(child);
    return child;
  }

  void updateObject(Obj object) {
    if (this.object is! Class && object is Class) {
      for (final function in object.functions) {
        _createChild(function.name, function);
      }
      for (final field in object.fields) {
        _createChild(field.name, field);
      }
      _sortEntriesByType();
    }
    this.object = object;
  }

  /// Clear the _childrenAsMap map recursively to save memory.
  void _trimChildrenAsMapEntries() {
    _childrenAsMap.clear();

    for (var child in children) {
      child._trimChildrenAsMapEntries();
    }
  }

  void _sortEntriesByType() {
    final scriptNodes = <VMServiceObjectNode>[];
    final classNodes = <VMServiceObjectNode>[];
    final functionNodes = <VMServiceObjectNode>[];
    final variableNodes = <VMServiceObjectNode>[];
    final otherNodes = <VMServiceObjectNode>[];

    for (final child in children) {
      switch (child.object.runtimeType) {
        case ScriptRef:
        case Script:
        case LibraryRef:
        case Library:
          scriptNodes.add(child);
          break;
        case ClassRef:
        case Class:
          classNodes.add(child);
          break;
        case FuncRef:
        case Func:
          functionNodes.add(child);
          break;
        case FieldRef:
        case Field:
          variableNodes.add(child);
          break;
        default:
          print('OTHER!');
          otherNodes.add(child);
      }
      child._sortEntriesByType();
    }

    scriptNodes.sort((a, b) {
      final scriptA = a.object as dynamic;
      final scriptB = b.object as dynamic;
      return scriptA.uri.compareTo(scriptB.uri);
    });

    classNodes.sort((a, b) {
      final objA = a.object as ClassRef;
      final objB = b.object as ClassRef;
      return objA.name.compareTo(objB.name);
    });

    functionNodes.sort((a, b) {
      final objA = a.object as FuncRef;
      final objB = b.object as FuncRef;
      return objA.name.compareTo(objB.name);
    });

    variableNodes.sort((a, b) {
      final objA = a.object as FieldRef;
      final objB = b.object as FieldRef;
      return objA.name.compareTo(objB.name);
    });

    children.clear();
    children.addAll([
      ...scriptNodes,
      ...classNodes,
      ...functionNodes,
      ...variableNodes,
      ...otherNodes,
    ]);
  }

  @override
  int get hashCode => script?.uri.hashCode ?? object?.hashCode ?? name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! VMServiceObjectNode) return false;
    final VMServiceObjectNode node = other;

    return node.name == name &&
        node.object == object &&
        node.script?.uri == script?.uri;
  }

  @override
  TreeNode<VMServiceObjectNode> shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}

/// Picker that takes a list of scripts and allows filtering and selection of
/// items.
class ObjectTreePicker extends StatefulWidget {
  const ObjectTreePicker({
    Key key,
    this.libraryFilterFocusNode,
  }) : super(key: key);

  final FocusNode libraryFilterFocusNode;

  @override
  ObjectTreePickerState createState() => ObjectTreePickerState();
}

class ObjectTreePickerState extends State<ObjectTreePicker> {
  // TODO(devoncarew): How to retain the filter text state?
  final _filterController = TextEditingController();
  ObjectTreeController controller;

  final _maxAutoExpandChildCount = 20;
  final _shouldFilterExpando = Expando<bool>('shouldFilter');

  int _filteredCount = 0;
  List<VMServiceLibraryContents> _filteredItems;
  List<VMServiceObjectNode> _rootObjectNodes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = Provider.of<ObjectTreeController>(context);
    // Set the initial nodes
    controller.initialized.then((_) => updateFilter());
    //controller.initialize();
  }

  @override
  void didUpdateWidget(ObjectTreePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller = Provider.of<ObjectTreeController>(context);
    controller.initialized.then((_) => updateFilter());
    //controller.initialize();
  }

  void updateFilter() {
    setState(_updateFiltered);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ObjectTreeController>(context);

    return FutureBuilder(
      future: controller.initialized,
      builder: (context, snapshot) {
        return ValueListenableBuilder(
          valueListenable: controller.selected,
          builder: (context, value, _) {
            final theme = Theme.of(context);
            final isMacOS = HostPlatform.instance.isMacOS;
            final isLoading = _filteredItems == null;
            if (!isLoading &&
                controller.programStructure.isNotEmpty &&
                _rootObjectNodes == null) {
              // Re-calculate the tree of scripts if necessary.
              _rootObjectNodes = VMServiceObjectNode.createRootsFrom(
                _filteredItems,
                _shouldFilterExpando,
              );

              int libCount = 0;
              int classCount = 0;
              int fieldCount = 0;
              int scriptCount = 0;
              int functionCount = 0;
              _filteredCount = _rootObjectNodes.fold(0, (prev, e) {
                int count = 0;
                breadthFirstTraversal<VMServiceObjectNode>(e, action: (e) {
                  if (e.object is LibraryRef) libCount++;
                  if (e.object is FuncRef) functionCount++;
                  if (e.object is ClassRef) classCount++;
                  if (e.object is FieldRef) fieldCount++;
                  if (e.object is ScriptRef) scriptCount++;
                  if (e.isSelectable) {
                    count++;
                  }
                });
                return prev + count;
              });
              print(
                  'Tree Count: libs: $libCount classes: $classCount fields: $fieldCount scripts: $scriptCount functions: $functionCount total: ${libCount + classCount + fieldCount + scriptCount + functionCount} count: $_filteredCount');
            }
            return OutlineDecoration(
              child: Column(
                children: [
                  AreaPaneHeader(
                    title: const Text('Program Explorer'),
                    needsTopBorder: false,
                    rightActions: [
                      ValueListenableBuilder(
                          valueListenable: controller.objectCount,
                          builder: (context, count, _) {
                            return CountBadge(
                              filteredItemsLength: _filteredCount,
                              //filteredItemsLength: DartObjectInspector.controller.topLevelObjectCount,
                              itemsLength: count,
                            );
                          }),
                      IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.refresh),
                        onPressed: () => controller.refresh().then(
                              (_) => setState(() {}),
                            ),
                      )
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.focusColor),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(denseSpacing),
                      child: SizedBox(
                        height: defaultTextFieldHeight,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                // TODO(bkonyi): move focusLibraryFilterKeySet into a common file.
                                'Filter (${focusLibraryFilterKeySet.describeKeys(isMacOS: isMacOS)})',
                            border: const OutlineInputBorder(),
                          ),
                          controller: _filterController,
                          onChanged: (value) => updateFilter(),
                          style: Theme.of(context).textTheme.bodyText2,
                          focusNode: widget.libraryFilterFocusNode,
                        ),
                      ),
                    ),
                  ),
                  if (isLoading)
                    const Expanded(
                      child: CenteredCircularProgressIndicator(),
                    )
                  else
                    Expanded(
                      child: TreeView<VMServiceObjectNode>(
                        onTraverse: (node) {
                          // Auto expand children when there are minimal search results.
                          if (_filterController.text.isNotEmpty &&
                              node.children.length <=
                                  _maxAutoExpandChildCount &&
                              node.object is! ClassRef) {
                            node.expand();
                          }
                        },
                        itemExtent: listItemHeight,
                        dataRoots: _rootObjectNodes,
                        onItemPressed: (node) async {
                          if (node.object != null && node.object is! Obj) {
                            await controller.populateNode(node);
                          }
                        },
                        dataDisplayProvider: (item, onTap) {
                          return _displayProvider(context, item, onTap);
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _buildFieldTypeText(Field field) {
    final buffer = StringBuffer();
    if (field.isStatic) {
      buffer.write('static ');
    }
    if (field.isConst) {
      buffer.write('const ');
    }
    if (field.isFinal && !field.isConst) {
      buffer.write('final ');
    }
    buffer.write(field.declaredType.name);
    return buffer.toString();
  }

  /// Builds a string representation of a function signature
  ///
  /// Examples:
  ///   - Foo<T>(T) -> dynamic
  ///   - Bar(String, int) -> void
  ///   - Baz(String, [int]) -> void
  ///   - Faz(String, {String? bar, required int baz}) -> int
  String _buildFunctionTypeText(
    String functionName,
    InstanceRef signature, {
    bool isInstanceMethod = false,
  }) {
    final buffer = StringBuffer();
    if (signature.typeParameters != null) {
      final typeParams = signature.typeParameters;
      buffer.write('<');
      for (int i = 0; i < typeParams.length; ++i) {
        buffer.write(typeParams[i].name);
        if (i + 1 != typeParams.length) {
          buffer.write(', ');
        }
      }
      buffer.write('>');
    }
    buffer.write('(');
    String closingTag;
    for (int i = isInstanceMethod ? 1 : 0;
        i < signature.parameters.length;
        ++i) {
      final param = signature.parameters[i];
      if (!param.fixed && closingTag == null) {
        if (param.name == null) {
          closingTag = ']';
          buffer.write('[');
        } else {
          closingTag = '}';
          buffer.write('{');
        }
      }
      if (param.required != null && param.required) {
        buffer.write('required ');
      }
      if (param.parameterType.name == null) {
        buffer.write(_buildFunctionTypeText('Function', param.parameterType));
      } else {
        buffer.write(param.parameterType.name);
      }
      if (param.name != null) {
        buffer.write(' ${param.name}');
      }
      if (i + 1 != signature.parameters.length) {
        buffer.write(', ');
      } else if (closingTag != null) {
        buffer.write(closingTag);
      }
    }
    buffer.write(') -> ');
    if (signature.returnType.name == null) {
      buffer.write(_buildFunctionTypeText('Function', signature.returnType));
    } else {
      buffer.write(signature.returnType.name);
    }

    return buffer.toString();
  }

  Widget _displayProvider(
    BuildContext context,
    VMServiceObjectNode node,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color iconColor = colorScheme.functionSyntaxColor;
    IconData icon = containerIcon;
    String subtext;
    String toolTip;

    if (node.object is ClassRef) {
      final clazz = node.object as ClassRef;
      icon = Icons.class_;
      iconColor = colorScheme.declarationsSyntaxColor;
      toolTip = 'class ${clazz.name}';
      if (clazz.typeParameters != null) {
        toolTip +=
            '<' + clazz.typeParameters.map((e) => e.name).join(', ') + '>';
      }
      subtext = toolTip;
    } else if (node.object is Func) {
      final func = node.object as Func;
      icon = Icons.functions;
      iconColor = colorScheme.functionSyntaxColor;
      final isInstanceMethod = func.owner is ClassRef;
      subtext = _buildFunctionTypeText(
        func.name,
        func.signature,
        isInstanceMethod: isInstanceMethod,
      );
      toolTip = '${func.name}$subtext';
    } else if (node.object is Field) {
      final field = node.object as Field;
      icon = Icons.equalizer;
      iconColor = colorScheme.variableSyntaxColor;
      subtext = _buildFieldTypeText(field);
      toolTip = '$subtext ${field.name}';
    } else if (node.object is ScriptRef || node.script != null) {
      icon = libraryIcon;
      iconColor = colorScheme.stringSyntaxColor;
      if (node.script != null) {
        subtext = node.script.uri;
        toolTip = subtext;
      }
    }

    return Tooltip(
      waitDuration: tooltipWait,
      preferBelow: false,
      message: toolTip ?? node.name,
      textStyle: theme.toolTipFixedFontStyle,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _handleSelected(onTap, node),
          child: Row(
            children: [
              Icon(
                icon,
                size: defaultIconSize,
                color: iconColor,
              ),
              const SizedBox(width: densePadding),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.fixedFontStyle,
                    ),
                    if (subtext != null)
                      Text(
                        subtext,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.subtleFixedFontStyle,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateFiltered() {
    final filterText = _filterController.text.trim().toLowerCase();

    print('Updating filter!');
    // TODO(bkonyi): allow for filtering on fields, classes, and functions.

    for (final ref in controller.programStructure) {
      bool includeLib = false;
      if (ref.lib.uri.caseInsensitiveFuzzyMatch(filterText)) {
        includeLib = true;
      }

      for (final script in ref.lib.scripts) {
        _shouldFilterExpando[script] = false;
        if (script.uri.caseInsensitiveFuzzyMatch(filterText)) {
          _shouldFilterExpando[script] = true;
        }
      }

      for (final clazz in ref.classes) {
        _shouldFilterExpando[clazz] = false;
        if (clazz.name.caseInsensitiveFuzzyMatch(filterText)) {
          includeLib = true;
          _shouldFilterExpando[clazz] = true;
        }
      }

      for (final function in ref.functions) {
        _shouldFilterExpando[function] = false;
        if (function.name.caseInsensitiveFuzzyMatch(filterText)) {
          includeLib = true;
          _shouldFilterExpando[function] = true;
        }
      }

      for (final field in ref.fields) {
        _shouldFilterExpando[field] = false;
        if (field.name.caseInsensitiveFuzzyMatch(filterText)) {
          includeLib = true;
          _shouldFilterExpando[field] = true;
        }
      }
      _shouldFilterExpando[ref.lib] = includeLib;
    }
    _filteredItems = controller.programStructure
        .where((ref) => _shouldFilterExpando[ref.lib])
        .toList();

    // Remove the cached value here; it'll be re-computed the next time we need
    // it.
    _rootObjectNodes = null;
  }

  Future<void> _handleSelected(Function onTap, VMServiceObjectNode node) async {
    onTap();
    controller.selectNode(node);
    setState(() {
      // Refresh selection.
    });
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({
    @required this.filteredItemsLength,
    @required this.itemsLength,
  });

  final int filteredItemsLength;
  final int itemsLength;

  @override
  Widget build(BuildContext context) {
    if (filteredItemsLength == itemsLength) {
      return Badge('${nf.format(itemsLength)}');
    } else {
      return Badge('${nf.format(filteredItemsLength)} of '
          '${nf.format(itemsLength)}');
    }
  }
}

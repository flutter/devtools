// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(rrousselGit) merge this code with the debugger view

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../eval_on_dart_library.dart';
import '../../inspector/inspector_text_styles.dart';
import '../../sliver_iterable_child_delegate.dart';
import '../../theme.dart';
import 'instance_details.dart';
import 'instance_providers.dart';

const typeColor = Color.fromARGB(255, 78, 201, 176);
const boolColor = Color.fromARGB(255, 86, 156, 214);
const nullColor = boolColor;
const numColor = Color.fromARGB(255, 181, 206, 168);
const stringColor = Color.fromARGB(255, 206, 145, 120);
const propertyColor = Color.fromARGB(255, 206, 145, 120);

const double rowHeight = 20.0;

final isExpandedProvider = StateProviderFamily<bool, InstancePath>((ref, path) {
  // expands the root by default, but not children
  return path.pathToProperty.isEmpty;
});

final estimatedChildCountProvider =
    AutoDisposeProviderFamily<int, InstancePath>((ref, rootPath) {
  int estimatedChildCount(InstancePath path) {
    int one(InstanceDetails instance) => 1;

    int expandableEstimatedChildCount(Iterable<PathToProperty> keys) {
      if (!ref.watch(isExpandedProvider(path)).state) {
        return 1;
      }
      return keys.fold(1, (acc, element) {
        return acc +
            estimatedChildCount(
              path.pathForChild(element),
            );
      });
    }

    return ref.watch(instanceProvider(path)).when(
          loading: () => 1,
          error: (err, stack) => 1,
          data: (instance) {
            return instance.map(
              nill: one,
              boolean: one,
              number: one,
              string: one,
              enumeration: one,
              map: (instance) {
                return expandableEstimatedChildCount(
                  instance.keys.map(
                      (key) => PathToProperty.mapKey(ref: key.instanceRefId)),
                );
              },
              list: (instance) {
                return expandableEstimatedChildCount(
                  List.generate(instance.length, $PathToProperty.listIndex),
                );
              },
              object: (instance) {
                return expandableEstimatedChildCount(
                  instance.fields.map(
                    (field) => PathToProperty.fromObjectField(field),
                  ),
                );
              },
            );
          },
        );
  }

  return estimatedChildCount(rootPath);
});

void showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $error')),
  );
}

class InstanceViewer extends StatefulWidget {
  const InstanceViewer({
    Key key,
    this.rootPath,
    @required this.showInternalProperties,
  }) : super(key: key);

  final InstancePath rootPath;
  final bool showInternalProperties;

  @override
  _InstanceViewerState createState() => _InstanceViewerState();
}

class _InstanceViewerState extends State<InstanceViewer> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Iterable<Widget> _buildError(
    Object error,
    StackTrace stackTrace,
    InstancePath path,
  ) {
    if (error is SentinelException) {
      return [Text(error.sentinel.valueAsString)];
    }

    return const [Text('<unknown error>')];
  }

  Iterable<Widget> _buildListViewItems(
    BuildContext context,
    ScopedReader watch, {
    @required InstancePath path,
    bool disableExpand = false,
  }) {
    return watch(instanceProvider(path)).when(
      loading: () => const [Text('loading...')],
      error: (err, stack) => _buildError(err, stack, path),
      data: (instance) sync* {
        final isExpanded = watch(isExpandedProvider(path));
        yield _buildHeader(
          instance,
          path: path,
          isExpanded: isExpanded,
          disableExpand: disableExpand,
        );

        if (isExpanded.state) {
          yield* instance.maybeMap(
            object: (instance) => _buildObjectItem(
              context,
              watch,
              instance,
              path: path,
            ),
            list: (list) => _buildListItem(
              context,
              watch,
              instance,
              path: path,
            ),
            map: (map) => _buildMapItem(
              context,
              watch,
              instance,
              path: path,
            ),
            // string/numbers/bools have no children, but this code can be reached
            // when the root of the instance tree (which is always expanded) is such primitive.
            orElse: () => const [],
          );
        }
      },
    );
  }

  Widget _buildHeader(
    InstanceDetails instance, {
    @required InstancePath path,
    StateController<bool> isExpanded,
    bool disableExpand = false,
  }) {
    return _Expandable(
      key: ValueKey(path),
      isExpandable: !disableExpand && instance.isExpandable,
      isExpanded: isExpanded,
      title: instance.map(
        enumeration: (instance) => _EditableField(
          setter: instance.setter,
          initialEditString: '${instance.type}.${instance.value}',
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: instance.type,
                  style: const TextStyle(color: typeColor),
                ),
                TextSpan(text: '.${instance.value}'),
              ],
            ),
          ),
        ),
        nill: (instance) => _EditableField(
          setter: instance.setter,
          initialEditString: 'null',
          child: const Text('null', style: TextStyle(color: nullColor)),
        ),
        string: (instance) => _EditableField(
          setter: instance.setter,
          initialEditString: '"${instance.displayString}"',
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '"'),
                TextSpan(
                  text: instance.displayString,
                  style: const TextStyle(color: stringColor),
                ),
                const TextSpan(text: '"'),
              ],
            ),
          ),
        ),
        number: (instance) => _EditableField(
          setter: instance.setter,
          initialEditString: instance.displayString,
          child: Text(
            instance.displayString,
            style: const TextStyle(color: numColor),
          ),
        ),
        boolean: (instance) => _EditableField(
          setter: instance.setter,
          initialEditString: instance.displayString,
          child: Text(
            instance.displayString,
            style: const TextStyle(color: boolColor),
          ),
        ),
        map: (instance) => _ObjectHeader(
          startToken: '{',
          endToken: '}',
          hash: instance.hash,
          meta: instance.keys.isEmpty
              ? null
              : instance.keys.length == 1
                  ? '1 element'
                  : '${instance.keys.length} elements',
        ),
        list: (instance) => _ObjectHeader(
          startToken: '[',
          endToken: ']',
          hash: instance.hash,
          meta: instance.length == 0
              ? null
              : instance.length == 1
                  ? '1 element'
                  : '${instance.length} elements',
        ),
        object: (instance) => _ObjectHeader(
          type: instance.type,
          hash: instance.hash,
          startToken: '',
          endToken: '',
          // Never show the number of elements when using custom objects
          meta: null,
        ),
      ),
    );
  }

  Iterable<Widget> _buildMapItem(
    BuildContext context,
    ScopedReader watch,
    MapInstance instance, {
    @required InstancePath path,
  }) sync* {
    for (final key in instance.keys) {
      final value = _buildListViewItems(
        context,
        watch,
        path: path.pathForChild(PathToProperty.mapKey(ref: key.instanceRefId)),
      );

      final keyHeader = _buildHeader(key, disableExpand: true, path: path);

      var isFirstItem = true;
      for (final child in value) {
        yield Padding(
          padding: const EdgeInsets.only(left: defaultSpacing),
          child: isFirstItem
              ? Row(
                  children: [
                    keyHeader,
                    const Text(': '),
                    Expanded(child: child),
                  ],
                )
              : child,
        );

        isFirstItem = false;
      }

      assert(
        !isFirstItem,
        'Bad state: the value of $key did not render any widget',
      );
    }
  }

  Iterable<Widget> _buildListItem(
    BuildContext context,
    ScopedReader watch,
    ListInstance instance, {
    @required InstancePath path,
  }) sync* {
    for (var index = 0; index < instance.length; index++) {
      final children = _buildListViewItems(
        context,
        watch,
        path: path.pathForChild(PathToProperty.listIndex(index)),
      );

      bool isFirst = true;

      for (final child in children) {
        Widget rowItem = child;

        // Add the item index only on the first line of the element
        if (isFirst) {
          isFirst = false;
          rowItem = Row(
            children: [
              Text('[$index]: '),
              Expanded(child: rowItem),
            ],
          );
        }

        yield Padding(
          padding: const EdgeInsets.only(left: defaultSpacing),
          child: rowItem,
        );
      }
    }
  }

  Iterable<Widget> _buildObjectItem(
    BuildContext context,
    ScopedReader watch,
    ObjectInstance instance, {
    @required InstancePath path,
  }) sync* {
    for (final field in instance.fields) {
      if (!widget.showInternalProperties &&
          field.isDefinedByDependency &&
          field.isPrivate) {
        // Hide private properties from classes defined by dependencies
        continue;
      }

      final children = _buildListViewItems(
        context,
        watch,
        path: path.pathForChild(PathToProperty.fromObjectField(field)),
      );

      bool isFirst = true;

      for (final child in children) {
        Widget rowItem = child;
        if (isFirst) {
          isFirst = false;
          rowItem = Row(
            children: [
              if (field.isFinal)
                Text(
                  'final ',
                  style: unimportant(Theme.of(context).colorScheme),
                ),
              Text('${field.name}: '),
              Expanded(child: rowItem),
            ],
          );
        }

        yield Padding(
          padding: const EdgeInsets.only(left: defaultSpacing),
          child: rowItem,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, watch, _) {
        return Scrollbar(
          isAlwaysShown: true,
          controller: scrollController,
          child: ListView.custom(
            controller: scrollController,
            // TODO: item height should be based on font size
            itemExtent: rowHeight,
            padding: const EdgeInsets.symmetric(
              vertical: denseSpacing,
              horizontal: defaultSpacing,
            ),
            childrenDelegate: SliverIterableChildDelegate(
              _buildListViewItems(
                context,
                watch,
                path: widget.rootPath,
                disableExpand: true,
              ),
              estimatedChildCount:
                  watch(estimatedChildCountProvider(widget.rootPath)),
            ),
          ),
        );
      },
    );
  }
}

class _ObjectHeader extends StatelessWidget {
  const _ObjectHeader({
    Key key,
    this.type,
    @required this.hash,
    @required this.meta,
    @required this.startToken,
    @required this.endToken,
  }) : super(key: key);

  final String type;
  final int hash;
  final String meta;
  final String startToken;
  final String endToken;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text.rich(
      TextSpan(
        children: [
          if (type != null)
            TextSpan(
              text: type,
              style: const TextStyle(color: typeColor),
            ),
          TextSpan(
            text: '#${shortHash(hash)}',
            style: unimportant(colorScheme),
          ),
          TextSpan(text: startToken),
          if (meta != null) TextSpan(text: meta),
          TextSpan(text: endToken),
        ],
      ),
    );
  }
}

class _EditableField extends StatefulWidget {
  const _EditableField({
    Key key,
    @required this.setter,
    @required this.child,
    @required this.initialEditString,
  }) : super(key: key);

  final Widget child;
  final String initialEditString;
  final Future<void> Function(String) setter;

  @override
  _EditableFieldState createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  final textFieldFocusNode = FocusNode();
  var isHovering = false;

  final _isAlive = Disposable();

  @override
  void dispose() {
    _isAlive.dispose();
    controller.dispose();
    focusNode.dispose();
    textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.setter == null) {
      return widget.child;
    }

    final colorScheme = Theme.of(context).colorScheme;

    final editingChild = TextField(
      autofocus: true,
      controller: controller,
      focusNode: textFieldFocusNode,
      onSubmitted: (value) async {
        try {
          if (widget.setter != null) {
            await widget.setter(value);
          }
        } catch (err) {
          showErrorSnackBar(context, err);
        }
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(densePadding),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(5)),
          borderSide: BorderSide(color: colorScheme.surface),
        ),
      ),
    );

    final displayChild = Stack(
      clipBehavior: Clip.none,
      children: [
        if (isHovering)
          Positioned(
            bottom: -5,
            left: -5,
            top: -5,
            right: -5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(defaultBorderRadius),
                ),
                border: Border.all(color: colorScheme.surface),
              ),
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            focusNode.requestFocus();
            textFieldFocusNode.requestFocus();
            controller.text = widget.initialEditString;
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: widget.initialEditString.length,
            );
          },
          child: Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: widget.child,
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isEditing = focusNode.hasFocus;

        return Focus(
          focusNode: focusNode,
          onKey: (node, key) {
            if (key.data.physicalKey == PhysicalKeyboardKey.escape) {
              focusNode.unfocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => isHovering = true),
            onExit: (_) => setState(() => isHovering = false),
            // use a Stack to show the borders, to avoid the UI "moving" when hovering
            child: isEditing ? editingChild : displayChild,
          ),
        );
      },
    );
  }
}

class _Expandable extends StatelessWidget {
  const _Expandable({
    Key key,
    @required this.isExpanded,
    @required this.isExpandable,
    @required this.title,
  }) : super(key: key);

  final StateController isExpanded;
  final bool isExpandable;
  final Widget title;

  @override
  Widget build(BuildContext context) {
    if (!isExpandable) {
      return Align(
        alignment: Alignment.centerLeft,
        child: title,
      );
    }

    return GestureDetector(
      onTap: () => isExpanded.state = !isExpanded.state,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: isExpanded.state ? 0 : -math.pi / 2),
            duration: defaultDuration,
            builder: (context, angle, _) {
              return Transform.rotate(
                angle: angle,
                child: const Icon(
                  Icons.expand_more,
                  size: defaultIconSize,
                ),
              );
            },
          ),
          title,
        ],
      ),
    );
  }
}

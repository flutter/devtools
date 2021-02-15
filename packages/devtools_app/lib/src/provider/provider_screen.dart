// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedantic/pedantic.dart';

import '../common_widgets.dart';
import '../config_specific/logger/logger.dart';
import '../eval_on_dart_library.dart';
import '../globals.dart';
import '../inspector/inspector_text_styles.dart';
import '../inspector/inspector_tree.dart';
import '../screen.dart';
import '../split.dart';
import 'eval.dart';
import 'provider_state_controller.dart';

const kTypeColor = Color.fromARGB(255, 78, 201, 176);
const kBoolColor = Color.fromARGB(255, 86, 156, 214);
const kNullColor = kBoolColor;
const kNumColor = Color.fromARGB(255, 181, 206, 168);
const kStringColor = Color.fromARGB(255, 206, 145, 120);
const kPropertyColor = Color.fromARGB(255, 206, 145, 120);

const double rowHeight = 20.0;
const double horizontalSpacing = 15;
const double expandIconSize = 20;

final _providerIdProvider = ScopedProvider<String>(null);

final AutoDisposeStateProvider<String> _selectedProviderIdProvider =
    AutoDisposeStateProvider<String>((ref) {
  final providerIdsStream = ref.watch(providerIdsProvider.stream);

  StreamSubscription sub;
  sub = providerIdsStream.where((ids) => ids.isNotEmpty).listen((ids) {
    sub.cancel();
    ref.read(_selectedProviderIdProvider).state = ids.first;
  });

  ref.onDispose(sub.cancel);

  return null;
});

final _hasSelectedProviderProvider = AutoDisposeProvider<bool>((ref) {
  return ref.watch(_selectedProviderIdProvider).state != null;
});

final _isSelectedProvider = ScopedProvider<bool>((watch) {
  return watch(_selectedProviderIdProvider).state == watch(_providerIdProvider);
});

final _isExpandedProvider =
    AutoDisposeStateProviderFamily<bool, InstancePath>((ref, path) {
  // TODO refreshing the provider (after evaluating an expression) should not reset the expansion state
  // expands the root by default, but not children
  return path.pathToProperty.isEmpty;
});

final _selectedProviderEvalProvider =
    AutoDisposeFutureProvider<EvalOnDartLibrary>((ref) async {
  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);

  final selectedProviderId = ref.watch(_selectedProviderIdProvider).state;

  final instanceDetails = await ref.watch(
    instanceProvider(InstancePath.fromProvider(selectedProviderId)).future,
  );

  return instanceDetails.maybeMap(
    object: (instance) => instance.evalForInstance,
    orElse: () => ref.watch(evalProvider),
  );
});

class ProviderScreen extends Screen {
  const ProviderScreen()
      : super.conditional(
          id: id,
          requiresLibrary: 'package:provider/',
          title: 'Provider',
          icon: Icons.palette,
        );

  static const id = 'provider';

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _ProviderScreenBody());
  }
}

class _ProviderScreenBody extends ConsumerWidget {
  const _ProviderScreenBody({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, ScopedReader watch) {
    final splitAxis = Split.axisFor(context, 0.85);

    return Split(
      axis: splitAxis,
      initialFractions: const [0.33, 0.67],
      children: [
        const _SplitBorder(child: _ProviderList()),
        Column(
          children: [
            const Expanded(child: _SplitBorder(child: _ProviderValue())),
            if (watch(_hasSelectedProviderProvider)) ...[
              const SizedBox(height: 10),
              const _SplitBorder(child: _ProviderEvaluation()),
            ]
          ],
        ),
      ],
    );
  }
}

void _showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $error')),
  );
}

class _ProviderEvaluation extends StatefulWidget {
  const _ProviderEvaluation({Key key}) : super(key: key);

  @override
  _ProviderEvaluationState createState() => _ProviderEvaluationState();
}

class _ProviderEvaluationState extends State<_ProviderEvaluation> {
  final isAlive = IsAlive();

  @override
  void dispose() {
    isAlive.dispose();
    super.dispose();
  }

  Future<void> _evalExpression(
    FutureOr<EvalOnDartLibrary> evalFuture,
    String expression,
  ) async {
    try {
      final eval = await evalFuture;

      final selectedProviderId =
          context.read(_selectedProviderIdProvider).state;
      final providerInstance = await context.read(
        instanceProvider(InstancePath.fromProvider(selectedProviderId)).future,
      );

      await eval.safeEval(
        expression,
        isAlive: isAlive,
        scope: {
          r'$value': providerInstance.instanceRefId,
        },
      );

      unawaited(
        context.refresh(
          instanceProvider(InstancePath.fromProvider(selectedProviderId)),
        ),
      );

      await serviceManager.performHotReload();
    } catch (err) {
      _showErrorSnackBar(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Execute code against the value exposed by this provider'),
          Consumer(
            builder: (context, watch, _) {
              final eval = watch(_selectedProviderEvalProvider.future);

              return TextField(
                onSubmitted: (value) => _evalExpression(eval, value),
                decoration: const InputDecoration(
                  hintText: r'$value.increment()',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProviderList extends ConsumerWidget {
  const _ProviderList({Key key}) : super(key: key);
  @override
  Widget build(BuildContext context, ScopedReader watch) {
    final state = watch(providerIdsProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('Error $err\n\n$stack'),
      ),
      data: (providerNodes) {
        return Scrollbar(
          child: ListView.builder(
            itemCount: providerNodes.length,
            itemBuilder: (context, index) {
              return ProviderScope(
                overrides: [
                  _providerIdProvider.overrideWithValue(providerNodes[index])
                ],
                child: const _ProviderNodeItem(),
              );
            },
          ),
        );
      },
    );
  }
}

class _SplitBorder extends StatelessWidget {
  const _SplitBorder({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).focusColor),
      ),
      child: child,
    );
  }
}

class _ProviderNodeItem extends ConsumerWidget {
  const _ProviderNodeItem({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, ScopedReader watch) {
    final providerId = watch(_providerIdProvider);
    final state = watch(providerNodeProvider(providerId));

    final isSelected = watch(_isSelectedProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isSelected ? colorScheme.selectedRowBackgroundColor : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.read(_selectedProviderIdProvider).state = providerId,
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: state.when(
          loading: () => const CenteredCircularProgressIndicator(),
          error: (err, stack) => Text('<Failed to load> $err\n\n$stack'),
          data: (node) {
            return Text('${node.type}()');
          },
        ),
      ),
    );
  }
}

/// A delegate that allows using ListView with an undetermined list length
/// while preserve the "build only what is visible" behaviour.
class SliverIterableChildDelegate extends SliverChildDelegate {
  SliverIterableChildDelegate(
    this.children, {
    this.estimatedChildCount,
  });

  final Iterable<Widget> children;
  int _lastAccessedIndex;
  Iterator<Widget> _lastAccessedIterator;

  @override
  Widget build(BuildContext context, int index) {
    if (_lastAccessedIndex == null || _lastAccessedIndex > index) {
      _lastAccessedIndex = -1;
      _lastAccessedIterator = children.iterator;
    }

    while (_lastAccessedIndex < index) {
      _lastAccessedIterator.moveNext();
      _lastAccessedIndex++;
    }

    return _lastAccessedIterator.current;
  }

  @override
  final int estimatedChildCount;

  @override
  bool shouldRebuild(SliverIterableChildDelegate oldDelegate) {
    return children != oldDelegate.children ||
        _lastAccessedIndex != oldDelegate._lastAccessedIndex ||
        _lastAccessedIterator != oldDelegate._lastAccessedIterator;
  }
}

class _ProviderValue extends ConsumerWidget {
  const _ProviderValue({Key key}) : super(key: key);

  Iterable<Widget> _buildError(Object error, StackTrace stackTrace) {
    if (error is SentinelException) {
      return [Text(error.sentinel.valueAsString)];
    }

    log(error, LogLevel.error);
    if (stackTrace != null) {
      log(stackTrace);
    }

    return const [Text('<unknown error>')];
  }

  Iterable<Widget> _buildListViewItems(
    BuildContext context,
    ScopedReader watch, {
    @required InstancePath path,
    bool disableExpand = false,
  }) {
    // TODO(rrousselGit): update riverpod to not prevent `watch` inside listview.builder
    return watch(instanceProvider(path)).when(
      // TODO: during loading, return the previous result to avoid flickers
      loading: () => const [Text('loading...')],
      error: _buildError,
      data: (instance) sync* {
        final isExpanded = watch(_isExpandedProvider(path));
        yield _buildHeader(
          instance,
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
            orElse: () => throw FallThroughError(),
          );
        }
      },
    );
  }

  Widget _buildHeader(
    InstanceDetails instance, {
    StateController<bool> isExpanded,
    bool disableExpand = false,
  }) {
    return _Expandable(
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
                  style: const TextStyle(color: kTypeColor),
                ),
                TextSpan(text: '.${instance.value}'),
              ],
            ),
          ),
        ),
        nill: (instance) => _EditableField(
          setter: instance.setter,
          initialEditString: 'null',
          child: const Text('null', style: TextStyle(color: kNullColor)),
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
                  style: const TextStyle(color: kStringColor),
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
            style: const TextStyle(color: kNumColor),
          ),
        ),
        boolean: (instance) => _EditableField(
          setter: instance.setter,
          initialEditString: instance.displayString,
          child: Text(
            instance.displayString,
            style: const TextStyle(color: kBoolColor),
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
          startToken: '(',
          endToken: ')',
          meta: instance.fieldsName.isEmpty
              ? null
              : instance.fieldsName.length == 1
                  ? '1 element'
                  : '${instance.fieldsName.length} elements',
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
        path: path.pathForChild(key.instanceRefId),
      );

      final keyHeader = _buildHeader(key, disableExpand: true);

      var isFirstItem = true;
      for (final child in value) {
        yield Padding(
          padding: const EdgeInsets.only(left: horizontalSpacing),
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
        path: path.pathForChild('$index'),
      );

      for (final child in children) {
        yield Padding(
          padding: const EdgeInsets.only(left: horizontalSpacing),
          child: child,
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
    for (final fieldName in instance.fieldsName) {
      final children = _buildListViewItems(
        context,
        watch,
        path: path.pathForChild(fieldName),
      );

      bool isFirst = true;

      for (final child in children) {
        Widget rowItem = child;
        if (isFirst) {
          isFirst = false;
          rowItem = Row(
            children: [
              Text('$fieldName: '),
              Expanded(child: rowItem),
            ],
          );
        }

        yield Padding(
          padding: const EdgeInsets.only(left: horizontalSpacing),
          child: rowItem,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, ScopedReader watch) {
    final selectedProviderId = watch(_selectedProviderIdProvider).state;

    if (selectedProviderId == null) {
      // TODO(rrousselGit) test selected provider being unmounted should select the next provider (or nothing)
      // A provider will automatically be selected as soon as one is detected
      return Container();
    }

    return Scrollbar(
      child: ListView.custom(
        // TODO: item height should be based on font size
        itemExtent: rowHeight,
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: horizontalSpacing,
        ),
        childrenDelegate: SliverIterableChildDelegate(
          _buildListViewItems(
            context,
            watch,
            path: InstancePath.fromProvider(selectedProviderId),
            disableExpand: true,
          ),
          // TODO add an estimate of the items count for the scrollbar to work properly
        ),
      ),
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
  final String hash;
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
              style: const TextStyle(color: kTypeColor),
            ),
          TextSpan(
            text: '#$hash',
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

  final _isAlive = IsAlive();

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
          _showErrorSnackBar(context, err);
        }
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
                borderRadius: const BorderRadius.all(Radius.circular(5)),
                border: Border.all(color: colorScheme.surface),
              ),
            ),
          ),
        GestureDetector(
          onTap: () {
            focusNode.requestFocus();
            textFieldFocusNode.requestFocus();
            controller.text = widget.initialEditString;
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: widget.initialEditString.length,
            );
          },
          child: widget.child,
        ),
      ],
    );

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isEditing = focusNode.hasFocus;

        return Focus(
          focusNode: focusNode,
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
            duration: const Duration(milliseconds: 200),
            builder: (context, angle, _) {
              return Transform.rotate(
                angle: angle,
                child: const Icon(
                  Icons.expand_more,
                  size: expandIconSize,
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

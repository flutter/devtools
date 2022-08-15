import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../devtools_app.dart';
import 'container_list.dart';
import 'nodes/riverpod_node.dart';
import 'selected_provider.dart';

class ProvidersList extends StatelessWidget {
  const ProvidersList({
    Key? key,
    required this.nodes,
    required this.addPadding,
  }) : super(key: key);

  final List<RiverpodNode> nodes;
  final bool addPadding;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final node in nodes)
          ContrainerProviderNodeElement(
            index: nodes.indexOf(node),
            key: Key('riverpod-${node.id}'),
            node: node,
          )
      ],
    );

    return addPadding
        ? Padding(
            padding: const EdgeInsets.only(left: 20),
            child: child,
          )
        : child;
  }
}

class ContrainerProviderNodeElement extends ConsumerWidget {
  const ContrainerProviderNodeElement({
    Key? key,
    required this.node,
    required this.index,
  }) : super(key: key);

  final RiverpodNode node;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(selectedNodeStateProvider)?.id == node.id;

    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isSelected ? colorScheme.selectedRowBackgroundColor : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(selectedNodeStateProvider.notifier).state = node;
      },
      child: Container(
        color: backgroundColor,
        padding: tilePadding,
        child: Row(
          children: [
            Expanded(
              child: Text(
                node.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (node.mightBeOutdated)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Tooltip(
                  message: "This provider's state might be out of date.",
                  child: Icon(
                    Icons.warning,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

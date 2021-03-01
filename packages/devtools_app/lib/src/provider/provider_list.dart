import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../globals.dart';
import '../inspector/inspector_tree.dart';
import '../instance_viewer/eval.dart';
import '../instance_viewer/instance_providers.dart';
import '../theme.dart';

const _tilePadding = const EdgeInsets.only(
  left: defaultSpacing,
  right: densePadding,
  top: densePadding,
  bottom: densePadding,
);

@immutable
class ProviderNode {
  const ProviderNode({
    @required this.id,
    @required this.type,
  });

  final String id;
  final String type;
}

final _providerListChanged = AutoDisposeStreamProvider<void>((ref) {
  return serviceManager.service.onExtensionEvent.where((event) {
    return event.extensionKind == 'provider:provider_list_changed';
  });
});

final providerIdsProvider =
    AutoDisposeStreamProvider<List<String>>((ref) async* {
  // cause the list of providers to be re-evaluated when notified of a change
  ref.watch(_providerListChanged);

  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);

  final eval = ref.watch(providerEvalProvider);

  final providerIdRefs = await eval.evalInstance(
    'ProviderBinding.debugInstance.providerDetails.keys.toList()',
    isAlive: isAlive,
  );

  final providerIdInstances = await Future.wait([
    for (final idRef in providerIdRefs.elements.cast<InstanceRef>())
      eval.getInstance(idRef, isAlive)
  ]);

  yield [
    for (final idInstance in providerIdInstances) idInstance.valueAsString,
  ];
});

final providerNodeProvider =
    AutoDisposeStreamProviderFamily<ProviderNode, String>((ref, id) async* {
  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);

  final eval = ref.watch(providerEvalProvider);

  final providerNodeInstance = await eval.evalInstance(
    "ProviderBinding.debugInstance.providerDetails['$id']",
    isAlive: isAlive,
  );

  Future<Instance> getFieldWithName(String name) {
    return eval.getInstance(
      providerNodeInstance.fields.firstWhere((e) => e.decl.name == name).value
          as InstanceRef,
      isAlive,
    );
  }

  final type = await getFieldWithName('type');

  yield ProviderNode(
    id: id,
    type: type.valueAsString,
  );
});

final _providerIdProvider = ScopedProvider<String>(null);

final _isSelectedProvider = ScopedProvider<bool>((watch) {
  return watch(selectedProviderIdProvider).state == watch(_providerIdProvider);
});

final AutoDisposeStateProvider<String> selectedProviderIdProvider =
    AutoDisposeStateProvider<String>((ref) {
  final providerIdsStream = ref.watch(providerIdsProvider.stream);

  StreamSubscription<void> sub;
  sub = providerIdsStream.listen((ids) {
    final controller = ref.read(selectedProviderIdProvider);

    if (controller.state == null) {
      if (ids.isNotEmpty) controller.state = ids.first;
      return;
    }

    if (ids.isEmpty) {
      controller.state = null;
    } else if (!ids.contains(controller.state)) {
      controller.state = ids.first;
    }
  }, onError: (err) {
    // nothing to do here, but passing onError prevents tests from failing when
    // testing scenarios where providerIdsStream emits an error
  });

  ref.onDispose(sub.cancel);

  return null;
});

class ProviderList extends StatefulWidget {
  const ProviderList({Key key}) : super(key: key);

  @override
  _ProviderListState createState() => _ProviderListState();
}

class _ProviderListState extends State<ProviderList> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, watch, child) {
        final state = watch(providerIdsProvider);

        return state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => const Padding(
            padding: _tilePadding,
            child: Text('<unknown error>'),
          ),
          data: (providerNodes) {
            return Scrollbar(
              controller: scrollController,
              isAlwaysShown: true,
              child: ListView.builder(
                primary: false,
                controller: scrollController,
                itemCount: providerNodes.length,
                itemBuilder: (context, index) {
                  return ProviderScope(
                    key: Key('provider-${providerNodes[index]}'),
                    overrides: [
                      _providerIdProvider
                          .overrideWithValue(providerNodes[index])
                    ],
                    child: const ProviderNodeItem(),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class ProviderNodeItem extends ConsumerWidget {
  const ProviderNodeItem({Key key}) : super(key: key);

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
      onTap: () => context.read(selectedProviderIdProvider).state = providerId,
      child: Container(
        color: backgroundColor,
        padding: _tilePadding,
        child: state.when(
          loading: () => const CenteredCircularProgressIndicator(),
          error: (err, stack) => Text('<Failed to load> $err\n\n$stack'),
          data: (node) => Text('${node.type}()'),
        ),
      ),
    );
  }
}

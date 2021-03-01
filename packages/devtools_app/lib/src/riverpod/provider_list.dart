import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../globals.dart';
import '../inspector/inspector_tree.dart';
import '../instance_viewer/eval.dart';
import '../instance_viewer/instance_providers.dart';

part 'provider_list.freezed.dart';

final _containerListChanged = AutoDisposeStreamProvider<void>((ref) {
  return serviceManager.service.onExtensionEvent.where((event) {
    return event.extensionKind == 'riverpod:container_list_changed';
  });
});

final _containerIdsProvider =
    AutoDisposeFutureProvider<List<String>>((ref) async {
  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);
  final eval = ref.watch(riverpodEvalProvider);

  // cause the list of containers to be re-evaluated when notified of a change
  ref.watch(_containerListChanged);

  final containerIdRefs = await eval.evalInstance(
    'RiverpodBinding.debugInstance.containers.keys.toList()',
    isAlive: isAlive,
  );

  final containerIdInstances = await Future.wait(
    containerIdRefs.elements
        .cast<InstanceRef>()
        .map((ref) => eval.getInstance(ref, isAlive)),
  );

  return [
    for (final containerIdInstance in containerIdInstances)
      containerIdInstance.valueAsString,
  ];
});

final _providerListChanged =
    AutoDisposeStreamProviderFamily<void, String>((ref, containerId) {
  return serviceManager.service.onExtensionEvent.where((event) {
    return event.extensionKind == 'riverpod:provider_list_changed' &&
        event.extensionData.data['container_id'] == containerId;
  });
});

@freezed
abstract class ProviderNode with _$ProviderNode {
  const factory ProviderNode({
    @required String containerId,
    @required String providerRefId,
    @required String type,
  }) = _ProviderNode;
}

final providerIdsProvider =
    AutoDisposeFutureProvider<List<ProviderId>>((ref) async {
  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);
  final eval = ref.watch(riverpodEvalProvider);

  final providerIds = <ProviderId>[];
  final containerIds = await ref.watch(_containerIdsProvider.future);

  for (final containerId in containerIds) {
    // cause the list of ids to be re-evaluated when providers are added/removed on a container
    ref.watch(_providerListChanged(containerId));

    final providerRefs = await eval.safeEval(
      'RiverpodBinding.debugInstance.containers["$containerId"]!.debugProviderValues.keys.toList()',
      isAlive: isAlive,
    );

    final instance = await eval.getInstance(providerRefs, isAlive);

    for (final providerRef in instance.elements.cast<InstanceRef>()) {
      providerIds.add(
        ProviderId(
          containerId: containerId,
          providerRefId: providerRef.id,
        ),
      );
    }
  }

  return providerIds;
});

final providerNodeProvider =
    AutoDisposeFutureProviderFamily<ProviderNode, ProviderId>((ref, id) async {
  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);
  final eval = ref.watch(riverpodEvalProvider);

  final type = await eval.evalInstance(
    'provider.runtimeType.toString()',
    isAlive: isAlive,
    scope: {'provider': id.providerRefId},
  );

  return ProviderNode(
    containerId: id.containerId,
    providerRefId: id.providerRefId,
    type: type.valueAsString,
  );
});

final _providerIdProvider = ScopedProvider<ProviderId>(null);

final _isSelectedProvider = ScopedProvider<bool>((watch) {
  return watch(selectedProviderIdProvider).state == watch(_providerIdProvider);
});

final AutoDisposeStateProvider<ProviderId> selectedProviderIdProvider =
    AutoDisposeStateProvider<ProviderId>((ref) {
  // TODO test that going from 0 to 1 provider selects it
  // TODO test that going from 1 > 0 > 1 providers selects it
  ref.watch(providerIdsProvider.future).then((ids) {
    if (ids.isNotEmpty) ref.read(selectedProviderIdProvider).state = ids.first;
  });

  return null;
});

class ProviderList extends ConsumerWidget {
  const ProviderList({Key key}) : super(key: key);

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
                child: const ProviderNodeItem(),
              );
            },
          ),
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

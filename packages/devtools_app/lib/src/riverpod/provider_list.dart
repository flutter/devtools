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
import '../theme.dart';

part 'provider_list.freezed.dart';

const _tilePadding = EdgeInsets.only(
  left: defaultSpacing,
  right: densePadding,
  top: densePadding,
  bottom: densePadding,
);

final _containerListChanged = AutoDisposeStreamProvider<void>((ref) {
  return serviceManager.service.onExtensionEvent.where((event) {
    return event.extensionKind == 'riverpod:container_list_changed';
  });
});

final containerIdsProvider =
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
    @required String providerId,
    @required String type,
    @required @nullable String paramDisplayString,
  }) = _ProviderNode;
}

final providerIdsProvider =
    AutoDisposeStreamProvider<List<ProviderId>>((ref) async* {
  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);
  final eval = ref.watch(riverpodEvalProvider);

  final containerIds = await ref.watch(containerIdsProvider.future);

  final idsPerContainerFuture = containerIds.map((containerId) async {
    // cause the list of ids to be re-evaluated when providers are added/removed on a container
    ref.watch(_providerListChanged(containerId));

    final providerRefs = await eval.safeEval(
      'RiverpodBinding.debugInstance.containers["$containerId"]!.debugProviderValues.keys.toList()',
      isAlive: isAlive,
    );

    final instance = await eval.getInstance(providerRefs, isAlive);

    final idsFuture =
        instance.elements.cast<InstanceRef>().map((providerRef) async {
      final debugId = await eval.evalInstance(
        'provider.debugId',
        isAlive: isAlive,
        scope: {'provider': providerRef.id},
      );

      return ProviderId(
        containerId: containerId,
        providerId: debugId.valueAsString,
      );
    });

    return Future.wait(idsFuture);
  });

  final idsPerContainer = await Future.wait(idsPerContainerFuture);

  yield idsPerContainer
      .fold<List<ProviderId>>([], (acc, element) => acc..addAll(element));
});

final providerNodeProvider =
    AutoDisposeFutureProviderFamily<ProviderNode, ProviderId>((ref, id) async {
  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);
  final eval = ref.watch(riverpodEvalProvider);

  final providerRef = await eval.safeEval(
    'RiverpodBinding.debugInstance.containers["${id.containerId}"]'
    '!.debugProviderElements.firstWhere((p) => p.provider.debugId == "${id.providerId}").provider',
    isAlive: isAlive,
  );

  final type = await eval.safeEval(
    'provider.runtimeType.toString()',
    isAlive: isAlive,
    scope: {'provider': providerRef.id},
  );

  final param = await eval.safeEval(
    'provider.argument',
    isAlive: isAlive,
    scope: {'provider': providerRef.id},
  );

  return ProviderNode(
    containerId: id.containerId,
    providerId: id.providerId,
    type: type.valueAsString,
    paramDisplayString: param?.valueAsString,
  );
});

final _providerIdProvider = ScopedProvider<ProviderId>(null);

final _isSelectedProvider = ScopedProvider<bool>((watch) {
  return watch(selectedProviderIdProvider).state == watch(_providerIdProvider);
});

final AutoDisposeStateProvider<ProviderId> selectedProviderIdProvider =
    AutoDisposeStateProvider<ProviderId>((ref) {
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

class ProviderList extends ConsumerWidget {
  const ProviderList({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, ScopedReader watch) {
    final state = watch(providerIdsProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const Padding(
        padding: _tilePadding,
        child: Text('<unknown error>'),
      ),
      data: (providerNodes) {
        return Scrollbar(
          child: ListView.builder(
            itemCount: providerNodes.length,
            itemBuilder: (context, index) {
              return ProviderScope(
                key: Key(
                  'riverpod-${providerNodes[index].containerId}-${providerNodes[index].providerId}',
                ),
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
        padding: _tilePadding,
        child: state.when(
          loading: () => const CenteredCircularProgressIndicator(),
          error: (err, stack) => Text('<Failed to load> $err\n\n$stack'),
          data: (node) {
            final param = node.paramDisplayString != null
                ? '(param: ${node.paramDisplayString})'
                : '()';

            return Text('${node.type}$param');
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vm_service/vm_service.dart';

import '../../../devtools_app.dart';
import '../provider/instance_viewer/eval.dart';
import 'nodes/container_node.dart';
import 'providers_list.dart';
import 'riverpod_eval.dart';

const _maxSupportedBindingVersion = 1;

final _containerIdsProvider = AutoDisposeFutureProvider<List<String>>(
  (ref) async {
    // recompute the list of containers on hot-restart
    ref.watch(hotRestartEventProvider);
    // cause the list of containers to be re-evaluated when notified of a change
    ref.watch(_riverpodContainerListChanged);

    final riverpodEval = await ref.watch(riverpodEvalFunctionProvider.future);
    final containerIdRefs = await riverpodEval('containerNodes.keys.toList()');

    return [
      for (final idInstance in containerIdRefs.elements!)
        idInstance.valueAsString!,
    ];
  },
  name: '_containerIdsProvider',
);

final supportsDevToolProvider = FutureProvider.autoDispose(
  (ref) async {
    final riverpodEval = await ref.watch(riverpodEvalFunctionProvider.future);
    final bindingVersionInstance = await riverpodEval('bindingVersion');
    final bindingVersion = int.parse(bindingVersionInstance.valueAsString!);
    return bindingVersion >= _maxSupportedBindingVersion;
  },
  name: 'supportsDevToolProvider',
);

const _riverpodEvents = [
  'riverpod:container_list_changed',
  'riverpod:provider_changed',
];
final _riverpodContainerListChanged = StreamProvider.autoDispose<void>(
  (ref) async* {
    final service = await ref.watch(serviceProvider.future);

    yield* service.onExtensionEvent.where((event) {
      return _riverpodEvents.contains(event.extensionKind);
    });
  },
  name: '_riverpodContainerListChanged',
);

final _containerNodeProvider =
    FutureProvider.autoDispose.family<ContainerNode, String>(
  (ref, id) async {
    // recompute the container information on hot-restart
    ref.watch(hotRestartEventProvider);
    // cause the container to be re-evaluated when notified of a change
    ref.watch(_riverpodContainerListChanged);

    final riverpodEval = await ref.watch(riverpodEvalFunctionProvider.future);
    final providerElementsInstance = await riverpodEval(
      'containerNodes["$id"]',
    );

    final evalField = await ref.watch(evalFieldFunctionProvider.future);
    final riverpodNodes = await evalField(
      'riverpodNodes',
      providerElementsInstance,
    );

    final providers = await Future.wait(
      riverpodNodes.associations!.map((a) => a.value).cast<InstanceRef>().map(
        (element) async {
          final evalInstance = await ref.watch(
            evalInstanceFunctionProvider.future,
          );
          final riverpodNodeInstance = await evalInstance(element);

          return ref.watch(
            evalRiverpodNodeProvider(riverpodNodeInstance).future,
          );
        },
      ),
    );

    return ContainerNode(
      id: id,
      providers: providers,
    );
  },
  name: '_containerNodeProvider',
);

/// Combines [_containerIdsProvider] with [_containerNodeProvider] to obtain all
/// the [ContainerNode]s at once, with their providers sorted by title.
final containerNodesProvider = FutureProvider.autoDispose<List<ContainerNode>>(
  (ref) async {
    final ids = await ref.watch(_containerIdsProvider.future);

    final nodes = await Future.wait<ContainerNode>(
      ids.map((id) => ref.watch(_containerNodeProvider(id).future)),
    );

    return nodes
        .map(
          (n) => n.copy(
            providers: n.providers..sort((a, b) => a.name.compareTo(b.name)),
          ),
        )
        .toList();
  },
  name: 'containerNodesProvider',
);

/// Returns `true` if the application is using more than one container.
final multiContainerProvider = FutureProvider.autoDispose<bool>((ref) async {
  final containers = await ref.watch(containerNodesProvider.future);
  return containers.length > 1;
});

const tilePadding = EdgeInsets.only(
  left: defaultSpacing,
  right: densePadding,
  top: densePadding,
  bottom: densePadding,
);

class ContainerList extends ConsumerStatefulWidget {
  const ContainerList({Key? key}) : super(key: key);

  @override
  _ContainerListState createState() => _ContainerListState();
}

class _ContainerListState extends ConsumerState<ContainerList> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(containerNodesProvider);
    final multiContainer =
        ref.watch(multiContainerProvider).valueOrNull ?? false;

    return nodes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const Padding(
        padding: tilePadding,
        child: Text('<unknown error>'),
      ),
      data: (nodes) {
        return Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: ListView.builder(
            primary: false,
            controller: scrollController,
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              final node = nodes[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (multiContainer)
                    Container(
                      key: Key('container-${node.id}'),
                      padding: tilePadding,
                      child: Expanded(
                        child: Text(
                          'ProviderContainer #${node.id}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ProvidersList(
                    nodes: node.providers,
                    addPadding: multiContainer,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

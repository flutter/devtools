import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../devtools_app.dart';
import 'container_list.dart';
import 'selected_provider.dart';

class RiverpodScreen extends Screen {
  const RiverpodScreen()
      : super.conditional(
          id: id,
          requiresLibrary: 'package:riverpod/',
          title: 'Riverpod',
          requiresDebugBuild: true,
          icon: Icons.attach_file,
        );

  static const id = 'riverpod';

  @override
  Widget build(BuildContext context) {
    return const RiverpodScreenWrapper();
  }
}

class RiverpodScreenWrapper extends ConsumerWidget {
  const RiverpodScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiContainer = ref.watch(multiContainerProvider);

    return ref.watch(supportsDevToolProvider).when(
          loading: () => const Text('Loading...'),
          error: (_, __) => const _UnsupportedMessage(),
          data: (supportsDevTool) {
            if (!supportsDevTool) {
              return const _UnsupportedMessage();
            }

            final splitAxis = Split.axisFor(context, 0.85);

            return Split(
              axis: splitAxis,
              initialFractions: const [0.33, 0.67],
              children: [
                OutlineDecoration(
                  child: Column(
                    children: [
                      AreaPaneHeader(
                        needsTopBorder: false,
                        title: Text(
                          multiContainer.maybeWhen(
                            data: (multiContainer) =>
                                multiContainer ? 'ProviderContainers' : 'Providers',
                            orElse: () => '',
                          ),
                        ),
                      ),
                      const Expanded(
                        child: ContainerList(),
                      ),
                    ],
                  ),
                ),
                const SelectedProviderPanel(),
              ],
            );
          },
        );
  }
}

class _UnsupportedMessage extends StatelessWidget {
  const _UnsupportedMessage()
      : super(
          key: const Key('riverpod-unsupported-message'),
        );

  @override
  Widget build(BuildContext context) {
    return const Text(
      "The version of riverpod package that you're using does not "
      'support devtools, please update to a compatible version.',
    );
  }
}

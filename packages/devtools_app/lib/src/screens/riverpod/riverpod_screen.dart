import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../devtools_app.dart';
import 'container_list.dart';
import 'riverpod_eval.dart';
import 'selected_provider.dart';

final _supportsDevToolProvider = FutureProvider.autoDispose<bool>(
  (ref) async {
    try {
      final riverpodEval = await ref.watch(riverpodEvalFunctionProvider.future);
      final supportsDevToolRef = await riverpodEval('supportsDevTool');

      return supportsDevToolRef.valueAsString == 'true';
    } catch (_) {
      return false;
    }
  },
  name: '_supportsDevToolProvider',
);

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
    return ref.watch(_supportsDevToolProvider).maybeWhen(
          orElse: () => const Text('Loading...'),
          data: (supportsDevTool) {
            if (!supportsDevTool) {
              return const Text(
                "The version of riverpod package that you're using does not "
                'support devtools, please update to a compatible version.',
              );
            }

            final splitAxis = Split.axisFor(context, 0.85);

            return Split(
              axis: splitAxis,
              initialFractions: const [0.33, 0.67],
              children: [
                OutlineDecoration(
                  child: Column(
                    children: const [
                      AreaPaneHeader(
                        needsTopBorder: false,
                        title: Text('Containers'),
                      ),
                      Expanded(
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../devtools_app.dart';
import '../provider/instance_viewer/eval.dart';
import '../provider/instance_viewer/instance_details.dart';
import '../provider/instance_viewer/instance_viewer.dart';
import 'nodes/riverpod_node.dart';
import 'refresh_state_button.dart';
import 'riverpod_eval.dart';
import 'settings_dialog_button.dart';

final selectedNodeStateProvider = StateProvider<RiverpodNode?>(
  (ref) => null,
  name: 'selectedNodeStateProvider',
);

@visibleForTesting
final updatedRiverpodNodeProvider =
    FutureProvider.autoDispose.family<RiverpodNode?, RiverpodNode>(
  (ref, RiverpodNode node) async {
    // recompute the value on hot restart
    ref.watch(hotRestartEventProvider);
    // refresh the value when the refresh button is pressed
    ref.watch(refreshProvider);

    final riverpodEval = await ref.watch(riverpodEvalFunctionProvider.future);
    final nodeRef = await riverpodEval(
      'getProvider("${node.containerId}", "${node.id}")',
    );

    return ref.watch(evalRiverpodNodeProvider(nodeRef).future);
  },
  name: 'updatedRiverpodNodeProvider',
);

@visibleForTesting
final selectedNodeProvider = Provider.autoDispose(
  (ref) {
    final selectedNode = ref.watch(selectedNodeStateProvider);
    if (selectedNode == null) {
      return null;
    }
    final refreshedNode =
        ref.watch(updatedRiverpodNodeProvider(selectedNode)).valueOrNull;
    return refreshedNode;
  },
  name: 'selectedNodeProvider',
);

class SelectedProviderPanel extends ConsumerWidget {
  const SelectedProviderPanel({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNode = ref.watch(selectedNodeProvider);
    final detailsTitleText =
        selectedNode != null ? selectedNode.title : '[No provider selected]';

    return OutlineDecoration(
      child: Column(
        children: [
          AreaPaneHeader(
            needsTopBorder: false,
            title: Text(detailsTitleText),
            actions: const [
              SettingsDialogButton(),
              RefreshStateButton(),
            ],
          ),
          if (selectedNode != null)
            Expanded(
              child: InstanceViewer(
                rootPath: InstancePath.fromInstanceId(
                  selectedNode.stateId,
                ),
                showInternalProperties: ref.watch(showInternalsProvider),
              ),
            )
        ],
      ),
    );
  }
}

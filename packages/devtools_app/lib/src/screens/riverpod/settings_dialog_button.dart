import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../devtools_app.dart';
import '../../shared/dialogs.dart';

final showInternalsProvider = StateProvider<bool>(
  (ref) => false,
  name: 'showInternalsProvider',
);

class SettingsDialogButton extends StatelessWidget {
  const SettingsDialogButton({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SettingsOutlinedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => _StateInspectorSettingsDialog(),
        );
      },
    );
  }
}

class _StateInspectorSettingsDialog extends ConsumerWidget {
  static const title = 'State inspector configurations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DevToolsDialog(
      title: dialogTitleText(theme, title),
      content: Column(
        key: const Key('state-inspector-settings-dialog'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => ref
                .read(showInternalsProvider.notifier)
                .update((state) => !state),
            child: Row(
              children: [
                Checkbox(
                  value: ref.watch(showInternalsProvider),
                  onChanged: (_) => ref
                      .read(showInternalsProvider.notifier)
                      .update((state) => !state),
                ),
                const Text(
                  'Show private properties inherited from SDKs/packages',
                ),
              ],
            ),
          )
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}

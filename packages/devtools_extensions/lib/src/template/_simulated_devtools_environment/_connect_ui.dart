// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '_simulated_devtools_environment.dart';

@visibleForTesting
class VmServiceConnection extends StatelessWidget {
  const VmServiceConnection({
    super.key,
    required this.simController,
    required this.connected,
  });

  @visibleForTesting
  static const totalControlsHeight = 45.0;
  @visibleForTesting
  static const totalControlsWidth = 415.0;

  final SimulatedDevToolsController simController;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: totalControlsHeight,
      child: connected
          ? _ConnectedVmServiceDisplay(simController: simController)
          : _DisconnectedVmServiceDisplay(simController: simController),
    );
  }
}

class _ConnectedVmServiceDisplay extends StatelessWidget {
  const _ConnectedVmServiceDisplay({required this.simController});

  final SimulatedDevToolsController simController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debugging:',
              style: theme.regularTextStyle,
            ),
            Text(
              serviceManager.service!.wsUri ?? '--',
              style: theme.boldTextStyle,
            ),
          ],
        ),
        const Expanded(
          child: SizedBox(width: denseSpacing),
        ),
        DevToolsButton(
          elevated: true,
          label: 'Disconnect',
          onPressed: () {
            simController.updateVmServiceConnection(uri: null);
          },
        ),
      ],
    );
  }
}

class _DisconnectedVmServiceDisplay extends StatefulWidget {
  const _DisconnectedVmServiceDisplay({required this.simController});

  final SimulatedDevToolsController simController;

  @override
  State<_DisconnectedVmServiceDisplay> createState() =>
      _DisconnectedVmServiceDisplayState();
}

class _DisconnectedVmServiceDisplayState
    extends State<_DisconnectedVmServiceDisplay> {
  static const _connectFieldWidth = 300.0;

  late final TextEditingController _connectTextFieldController;

  @override
  void initState() {
    super.initState();
    _connectTextFieldController = TextEditingController();
  }

  @override
  void dispose() {
    _connectTextFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _connectFieldWidth,
          child: TextField(
            autofocus: true,
            style: theme.regularTextStyle,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(denseSpacing),
              isDense: true,
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(width: 0.5, color: theme.focusColor),
              ),
              labelText: 'Dart VM Service URL',
              labelStyle: theme.regularTextStyle,
              hintText: '(e.g., http://127.0.0.1:60851/fH-kAEXc7MQ=/)',
              hintStyle: theme.regularTextStyle,
            ),
            onSubmitted: (value) =>
                widget.simController.updateVmServiceConnection(uri: value),
            controller: _connectTextFieldController,
          ),
        ),
        const SizedBox(width: denseSpacing),
        DevToolsButton(
          elevated: true,
          label: 'Connect',
          onPressed: () {
            widget.simController.updateVmServiceConnection(
              uri: _connectTextFieldController.text,
            );
          },
        ),
      ],
    );
  }
}

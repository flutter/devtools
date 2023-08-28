// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '_simulated_devtools_environment.dart';

// TODO(kenz): delete this once we can bump to vm_service ^11.10.0
String? _connectedUri;

class _VmServiceConnection extends StatelessWidget {
  const _VmServiceConnection({
    required this.simController,
    required this.connected,
  });

  static const _totalControlsHeight = 45.0;
  static const _totalControlsWidth = 415.0;

  final _SimulatedDevToolsController simController;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _totalControlsHeight,
      child: connected
          ? const _ConnectedVmServiceDisplay()
          : _DisconnectedVmServiceDisplay(
              simController: simController,
            ),
    );
  }
}

class _ConnectedVmServiceDisplay extends StatelessWidget {
  const _ConnectedVmServiceDisplay();

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
            Text(_connectedUri ?? '--'),
            // TODO(kenz): uncomment once we can bump to vm_service ^11.10.0
            // Text(
            //   serviceManager.service!.wsUri ?? '--',
            //   style: theme.boldTextStyle,
            // ),
          ],
        ),
        const Expanded(
          child: SizedBox(width: denseSpacing),
        ),
        DevToolsButton(
          elevated: true,
          label: 'Disconnect',
          onPressed: () {
            _connectedUri = null;
            unawaited(serviceManager.manuallyDisconnect());
          },
        ),
      ],
    );
  }
}

class _DisconnectedVmServiceDisplay extends StatefulWidget {
  const _DisconnectedVmServiceDisplay({required this.simController});

  final _SimulatedDevToolsController simController;

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
                widget.simController.vmServiceConnectionChanged(uri: value),
            controller: _connectTextFieldController,
          ),
        ),
        const SizedBox(width: denseSpacing),
        DevToolsButton(
          elevated: true,
          label: 'Connect',
          onPressed: () {
            _connectedUri = _connectTextFieldController.text;
            widget.simController.vmServiceConnectionChanged(
              uri: _connectTextFieldController.text,
            );
          },
        ),
      ],
    );
  }
}

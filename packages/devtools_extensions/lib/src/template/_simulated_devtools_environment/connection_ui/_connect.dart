// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../_simulated_devtools_environment.dart';

class _UriConnectionDisplay extends StatelessWidget {
  const _UriConnectionDisplay({
    required this.simController,
    required this.connected,
    required this.connectedLabel,
    required this.disconnectedLabel,
    required this.disconnectedHint,
    required this.onConnect,
    required this.onDisconnect,
    required this.currentConnection,
    this.help,
  });

  @visibleForTesting
  static const totalControlsHeight = 45.0;

  final SimulatedDevToolsController simController;
  final bool connected;
  final String connectedLabel;
  final String disconnectedLabel;
  final String disconnectedHint;
  final void Function(String) onConnect;
  final VoidCallback onDisconnect;
  final String Function() currentConnection;
  final Widget? help;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: totalControlsHeight,
      child: connected
          ? _ConnectedDisplay(
              simController: simController,
              label: connectedLabel,
              onDisconnect: onDisconnect,
              currentConnection: currentConnection,
              help: help,
            )
          : _DisconnectedDisplay(
              simController: simController,
              label: disconnectedLabel,
              hint: disconnectedHint,
              onConnect: onConnect,
              help: help,
            ),
    );
  }
}

class _ConnectedDisplay extends StatelessWidget {
  const _ConnectedDisplay({
    required this.simController,
    required this.label,
    required this.currentConnection,
    required this.onDisconnect,
    this.help,
  });

  final SimulatedDevToolsController simController;
  final String label;
  final String Function() currentConnection;
  final VoidCallback onDisconnect;
  final Widget? help;

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
              label,
              style: theme.regularTextStyle,
            ),
            Text(
              currentConnection(),
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
          onPressed: onDisconnect,
        ),
        if (help != null) ...[
          const SizedBox(width: denseSpacing),
          _ConnectionHelpButton(
            dialogTitle: '$label help',
            child: help!,
          ),
        ],
      ],
    );
  }
}

class _DisconnectedDisplay extends StatefulWidget {
  const _DisconnectedDisplay({
    required this.simController,
    required this.label,
    required this.hint,
    required this.onConnect,
    this.help,
  });

  final SimulatedDevToolsController simController;
  final String label;
  final String hint;
  final void Function(String) onConnect;
  final Widget? help;

  @override
  State<_DisconnectedDisplay> createState() => _DisconnectedDisplayState();
}

class _DisconnectedDisplayState extends State<_DisconnectedDisplay> {
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
              labelText: widget.label,
              labelStyle: theme.regularTextStyle,
              hintText: widget.hint,
              hintStyle: theme.regularTextStyle,
            ),
            onSubmitted: widget.onConnect,
            controller: _connectTextFieldController,
          ),
        ),
        const SizedBox(width: denseSpacing),
        DevToolsButton(
          elevated: true,
          label: 'Connect',
          onPressed: () => widget.onConnect(_connectTextFieldController.text),
        ),
        if (widget.help != null) ...[
          const SizedBox(width: denseSpacing),
          _ConnectionHelpButton(
            dialogTitle: '${widget.label} help',
            child: widget.help!,
          ),
        ],
      ],
    );
  }
}

class _ConnectionHelpButton extends StatelessWidget {
  const _ConnectionHelpButton({
    required this.dialogTitle,
    required this.child,
  });

  final String dialogTitle;

  final Widget child;

  static const helpContentWidth = 550.0;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton.iconOnly(
      icon: Icons.help_outline,
      tooltip: 'Help',
      onPressed: () {
        showDevToolsDialog(
          context: context,
          title: dialogTitle,
          content: SizedBox(
            width: helpContentWidth,
            child: child,
          ),
        );
      },
    );
  }
}

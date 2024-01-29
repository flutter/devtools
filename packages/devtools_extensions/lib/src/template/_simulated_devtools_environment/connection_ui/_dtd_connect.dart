// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../_simulated_devtools_environment.dart';

@visibleForTesting
class DTDConnectionDisplay extends StatelessWidget {
  const DTDConnectionDisplay({
    super.key,
    required this.simController,
    required this.connected,
    required this.onConnectionChange,
  });

  @visibleForTesting
  static const totalControlsHeight = 45.0;
  @visibleForTesting
  static const totalControlsWidth = 415.0;

  final SimulatedDevToolsController simController;
  final bool connected;
  final Future<void> Function(String?) onConnectionChange;

  @override
  Widget build(BuildContext context) {
    return _UriConnectionDisplay(
      simController: simController,
      connected: connected,
      connectedLabel: 'DTD connection: ',
      disconnectedLabel: 'Dart Tooling Daemon Connection',
      disconnectedHint: '(e.g., ws://127.0.0.1:57624)',
      // TODO(kenz): this needs handling for bad input.
      onConnect: (value) async {
        value = value.trim();
        if (value.startsWith('127.0.0.1')) {
          value = 'ws://$value';
        }
        await onConnectionChange(value);
        if (dtdManager.hasConnection) {
          simController.logInfoEvent(
            'Connected DTD to ${dtdManager.uri?.toString()}',
          );
        } else {
          simController.logInfoEvent('Failed to connect DTD to $value');
        }
      },
      onDisconnect: () async {
        await onConnectionChange(null);
        simController.logInfoEvent('Disconnected from DTD');
      },
      currentConnection: () => dtdManager.uri?.toString() ?? '--',
      help: const DtdHelp(),
    );
  }
}

class DtdHelp extends StatelessWidget {
  const DtdHelp({super.key});

  static const dtdStartCommand = 'dart tooling-daemon --disable-secrets';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTextStyle(
      style: theme.regularTextStyle,
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              style: theme.regularTextStyle,
              text:
                  'If your DevTools extension interacts with the Dart Tooling '
                  'Daemon (DTD) through',
              children: [
                TextSpan(
                  text: ' dtdManager ',
                  style: theme.boldTextStyle,
                ),
                const TextSpan(
                  text: 'then you will need to start a local instance of DTD '
                      'to debug these features in the simulated environment. '
                      'To start DTD locally:\n\n1. Run the following command '
                      'from your terminal:',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: defaultSpacing),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SelectableText(dtdStartCommand),
                const SizedBox(width: defaultSpacing),
                DevToolsButton.iconOnly(
                  icon: Icons.content_copy,
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: dtdStartCommand),
                    );
                  },
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              style: theme.regularTextStyle,
              text: '2. This will output text to the command line:',
              children: [
                TextSpan(
                  text: ' "The Dart Tooling Daemon is listening on '
                      '127.0.0.1:49390". ',
                  style: theme.boldTextStyle,
                ),
                const TextSpan(
                  text: 'Copy the DTD URI and paste it into the "Dart '
                      'Tooling Daemon Connection" text field to connect.',
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultSpacing),
          Text(
            'In a real environment, DTD will be started by the user\'s IDE or'
            ' by DevTools, so your extension will inherit the existing DTD'
            ' connection from DevTools.',
            style: theme.subtleTextStyle,
          ),
        ],
      ),
    );
  }
}

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
      connectedLabel: 'Dart Tooling Daemon connection: ',
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

  static const printDtdFlag = '--print-dtd';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTextStyle(
      style: theme.regularTextStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: theme.regularTextStyle,
              text:
                  'If your DevTools extension interacts with the Dart Tooling '
                  'Daemon (DTD) through ',
              children: [
                TextSpan(
                  text: 'dtdManager',
                  style: theme.boldTextStyle,
                ),
                const TextSpan(
                  text: ', then you will need to connect to a local instance '
                      'of DTD to debug these features in the simulated '
                      'environment. There are multiple ways to access a local '
                      'instance of DTD:\n\n'
                      '1. If you are running a Dart or Flutter application '
                      'from command line, add the ',
                ),
                TextSpan(
                  text: printDtdFlag,
                  style: theme.boldTextStyle,
                ),
                const TextSpan(
                  text: ' flag. This will output a Dart Tooling Daemon URI to '
                      'the command line that you can copy.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: defaultSpacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SelectableText(printDtdFlag),
                const SizedBox(width: defaultSpacing),
                DevToolsButton.iconOnly(
                  icon: Icons.content_copy,
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: printDtdFlag),
                    );
                  },
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              style: theme.regularTextStyle,
              text: '2. If you have a Dart or Flutter project open in your IDE '
                  '(VS Code, IntelliJ, or Android Studio), the IDE will have '
                  'a running instance of DTD that you can use. Use the '
                  'IDE\'s affordance to find an action (Command Pallette '
                  'for VS Code or Find Action for IntelliJ / Android '
                  'Studio) to search for the ',
              children: [
                TextSpan(
                  text: '"Copy DTD URI to Clipboard"',
                  style: theme.boldTextStyle,
                ),
                const TextSpan(
                  text: ' action.\n\n'
                      'Now, you should have a DTD URI in your clipboard. Paste '
                      'this into the "Dart Tooling Daemon Connection" text '
                      'field to connect.',
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultSpacing),
          Text(
            'In a real environment, your extension will inherit the existing '
            'DTD connection from DevTools.',
            style: theme.subtleTextStyle,
          ),
        ],
      ),
    );
  }
}

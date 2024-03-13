// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../_simulated_devtools_environment.dart';

@visibleForTesting
class VmServiceConnectionDisplay extends StatelessWidget {
  const VmServiceConnectionDisplay({
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
    return _UriConnectionDisplay(
      simController: simController,
      connected: connected,
      connectedLabel: 'Debugging: ',
      disconnectedLabel: 'Dart VM Service Connection',
      disconnectedHint: '(e.g., http://127.0.0.1:60851/fH-kAEXc7MQ=/)',
      onConnect: (value) => simController.updateVmServiceConnection(uri: value),
      onDisconnect: () => simController.updateVmServiceConnection(uri: null),
      currentConnection: () => serviceManager.serviceUri ?? '--',
      help: const VmServiceHelp(),
    );
  }
}

class VmServiceHelp extends StatelessWidget {
  const VmServiceHelp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTextStyle(
      style: theme.regularTextStyle,
      child: Column(
        children: [
          Text(
            'If your DevTools extension interacts with a running Dart '
            'application, then you will need to run a test application and '
            'connect it to the simulated environment.\n\n'
            '1. Run a Dart or Flutter application.\n',
            style: theme.regularTextStyle,
          ),
          RichText(
            text: TextSpan(
              style: theme.regularTextStyle,
              text: '2. This will output text to the command line:',
              children: [
                TextSpan(
                  text: ' "A Dart VM Service is available at: '
                      'http://127.0.0.1:53985/6RVz1q0e9ok=". ',
                  style: theme.boldTextStyle,
                ),
                const TextSpan(
                  text: 'Copy the VM Service URI and paste it into the "Dart '
                      'VM Service Connection" text field to connect.',
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultSpacing),
          Text(
            'In a real environment, your extension will inherit the existing '
            'VM Service connection from DevTools.',
            style: theme.subtleTextStyle,
          ),
        ],
      ),
    );
  }
}

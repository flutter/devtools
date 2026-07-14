// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../../shared/ui/common_widgets.dart';
import 'accessibility_controller.dart';

/// A screen that displays accessibility information.
class AccessibilityScreen extends Screen {
  AccessibilityScreen() : super.fromMetaData(ScreenMetaData.accessibility);

  static final id = ScreenMetaData.accessibility.id;

  @override
  Widget buildScreenBody(BuildContext context) =>
      const AccessibilityScreenBody();
}

class AccessibilityScreenBody extends StatefulWidget {
  const AccessibilityScreenBody({super.key});

  @override
  State<AccessibilityScreenBody> createState() =>
      _AccessibilityScreenBodyState();
}

class _AccessibilityScreenBodyState extends State<AccessibilityScreenBody>
    with AutoDisposeMixin {
  late AccessibilityController controller;

  @override
  void initState() {
    super.initState();
    controller = screenControllers.lookup<AccessibilityController>();
  }

  @override
  Widget build(BuildContext context) {
    final splitAxis = _splitAxisFor(context);
    return SplitPane(
      axis: splitAxis,
      initialFractions: const [0.6, 0.4],
      children: const [
        AccessibilitySemanticsTreePane(),
        AccessibilityOverridesPane(),
      ],
    );
  }

  Axis _splitAxisFor(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.width > 1000 ? Axis.horizontal : Axis.vertical;
  }
}

/// A pane that displays the semantics tree of the connected app.
class AccessibilitySemanticsTreePane extends StatelessWidget {
  const AccessibilitySemanticsTreePane({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsAreaPane(
      header: AreaPaneHeader(title: Text('Semantics Tree')),
      child: CenteredMessage(
        message:
            'Accessibility semantics tree placeholder.\n'
            '// TODO(hannah-hyj): Implement semantics tree view and details explorer.',
      ),
    );
  }
}

/// A pane that displays the accessibility overrides controls.
class AccessibilityOverridesPane extends StatelessWidget {
  const AccessibilityOverridesPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = screenControllers.lookup<AccessibilityController>();
    return DevToolsAreaPane(
      header: const AreaPaneHeader(title: Text('Accessibility Overrides')),
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simulate and test accessibility settings on the connected device in real-time.',
                style: theme.subtleTextStyle,
              ),
              const SizedBox(height: defaultSpacing),
              const Divider(),
              const SizedBox(height: denseSpacing),
              _BrightnessOverride(controller: controller),
              const SizedBox(height: defaultSpacing),
              _TextScaleOverride(controller: controller),
              const SizedBox(height: defaultSpacing),
              _SwitchOverride(
                label: 'Bold Text',
                description: 'Forces all text in the application to be bold.',
                notifier: controller.boldText,
              ),
              const SizedBox(height: defaultSpacing),
              _SwitchOverride(
                label: 'Screen Reader Debugger',
                description:
                    'Enables interactive screen reader simulation semantics.',
                notifier: controller.screenReader,
              ),
              const SizedBox(height: defaultSpacing),
              _SwitchOverride(
                label: 'High Contrast',
                description: 'Increases the contrast of text and icons.',
                notifier: controller.highContrast,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrightnessOverride extends StatelessWidget {
  const _BrightnessOverride({required this.controller});

  final AccessibilityController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brightness',
          style: theme.boldTextStyle,
        ),
        const SizedBox(height: densePadding),
        Text(
          'Override the color scheme mode of the app.',
          style: theme.subtleTextStyle,
        ),
        const SizedBox(height: denseSpacing),
        ValueListenableBuilder<String>(
          valueListenable: controller.brightness,
          builder: (context, value, _) {
            return RoundedDropDownButton<String>(
              isExpanded: true,
              value: value,
              items: const [
                DropdownMenuItem(
                  value: 'System',
                  child: Text('System Default'),
                ),
                DropdownMenuItem(
                  value: 'Light',
                  child: Text('Light Mode'),
                ),
                DropdownMenuItem(
                  value: 'Dark',
                  child: Text('Dark Mode'),
                ),
              ],
              onChanged: (newValue) {
                if (newValue != null) {
                  controller.brightness.value = newValue;
                }
              },
            );
          },
        ),
      ],
    );
  }
}

class _TextScaleOverride extends StatelessWidget {
  const _TextScaleOverride({required this.controller});

  final AccessibilityController controller;

  static const _minTextScale = 0.5;
  static const _maxTextScale = 3.0;
  static const _textScaleDivisions = 25;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: controller.textScale,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Text Scale',
                      style: theme.boldTextStyle,
                    ),
                    const SizedBox(height: densePadding),
                    Text(
                      'Scale the system font size.',
                      style: theme.subtleTextStyle,
                    ),
                  ],
                ),
                Text(
                  '${value.toStringAsFixed(2)}x',
                  style: theme.boldTextStyle,
                ),
              ],
            ),
            const SizedBox(height: densePadding),
            Slider(
              value: value,
              min: _minTextScale,
              max: _maxTextScale,
              divisions: _textScaleDivisions,
              onChanged: (newValue) {
                controller.textScale.value = newValue;
              },
            ),
          ],
        );
      },
    );
  }
}

class _SwitchOverride extends StatelessWidget {
  const _SwitchOverride({
    required this.label,
    required this.description,
    required this.notifier,
  });

  final String label;
  final String description;
  final ValueNotifier<bool> notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.boldTextStyle,
              ),
              const SizedBox(height: densePadding),
              Text(
                description,
                style: theme.subtleTextStyle,
              ),
            ],
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: notifier,
          builder: (context, enabled, _) {
            return Switch(
              value: enabled,
              onChanged: (newValue) {
                notifier.value = newValue;
              },
            );
          },
        ),
      ],
    );
  }
}



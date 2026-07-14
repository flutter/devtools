// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import '../../shared/ui/common_widgets.dart';
import 'accessibility_controller.dart';

/// A pane that displays the accessibility overrides controls.
class AccessibilityOverridesPane extends StatelessWidget {
  const AccessibilityOverridesPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = screenControllers.lookup<AccessibilityController>();
    return DevToolsAreaPane(
      header: const AreaPaneHeader(
        title: Text('Accessibility Overrides'),
        roundedTopBorder: false,
        includeTopBorder: false,
      ),
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
                description: 'Debug and test screen reader layouts.',
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

class _AccessibilityPanelLabel extends StatelessWidget {
  const _AccessibilityPanelLabel({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.boldTextStyle),
        const SizedBox(height: densePadding),
        Text(description, style: theme.subtleTextStyle),
      ],
    );
  }
}

class _BrightnessOverride extends StatelessWidget {
  const _BrightnessOverride({required this.controller});

  final AccessibilityController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AccessibilityPanelLabel(
          label: 'Brightness',
          description: 'Override the color scheme mode of the app.',
        ),
        const SizedBox(height: denseSpacing),
        ValueListenableBuilder<BrightnessOverride>(
          valueListenable: controller.brightness,
          builder: (context, value, _) {
            return RoundedDropDownButton<BrightnessOverride>(
              isExpanded: true,
              value: value,
              items: BrightnessOverride.values.map((option) {
                return DropdownMenuItem<BrightnessOverride>(
                  value: option,
                  child: Text(option.display),
                );
              }).toList(),
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
                const _AccessibilityPanelLabel(
                  label: 'Text Scale',
                  description: 'Scale the system font size.',
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
    return Row(
      children: [
        Expanded(
          child: _AccessibilityPanelLabel(
            label: label,
            description: description,
          ),
        ),
        NotifierSwitch(notifier: notifier),
      ],
    );
  }
}

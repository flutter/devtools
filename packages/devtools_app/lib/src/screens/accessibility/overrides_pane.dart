// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

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
              _ViewMetricsOverrides(controller: controller),
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

/// The controls of `ext.flutter.viewMetricsOverride`, which are disabled with
/// a tooltip while the app does not support it.
class _ViewMetricsOverrides extends StatelessWidget {
  const _ViewMetricsOverrides({required this.controller});

  final AccessibilityController controller;

  static const _unavailableMessage =
      'Unavailable because the connected app is a profile build, or uses a '
      'Flutter version that does not support these overrides.';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.overridesAvailable,
      builder: (context, available, _) {
        final overrides = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TextScaleOverride(controller: controller, enabled: available),
            const SizedBox(height: defaultSpacing),
            _SwitchOverride(
              label: 'Bold Text',
              description: 'Forces all text in the application to be bold.',
              value: controller.boldText,
              onChanged: available ? controller.setBoldText : null,
            ),
            const SizedBox(height: defaultSpacing),
            _SwitchOverride(
              label: 'Screen Reader Debugger',
              description: 'Debug and test screen reader layouts.',
              value: controller.screenReader,
              onChanged: available ? controller.setScreenReader : null,
            ),
            const SizedBox(height: defaultSpacing),
            _SwitchOverride(
              label: 'High Contrast',
              description: 'Increases the contrast of text and icons.',
              value: controller.highContrast,
              onChanged: available ? controller.setHighContrast : null,
            ),
          ],
        );
        if (available) return overrides;
        return DevToolsTooltip(message: _unavailableMessage, child: overrides);
      },
    );
  }
}

class _TextScaleOverride extends StatefulWidget {
  const _TextScaleOverride({required this.controller, required this.enabled});

  final AccessibilityController controller;

  /// Whether the text scale can be changed.
  final bool enabled;

  @override
  State<_TextScaleOverride> createState() => _TextScaleOverrideState();
}

class _TextScaleOverrideState extends State<_TextScaleOverride> {
  static const _minTextScale = 0.5;
  static const _maxTextScale = 3.0;
  static const _textScaleDivisions = 25;

  /// The text scale that the slider shows while the user moves it, until the
  /// app answers the override.
  double? _sliderTextScale;

  Future<void> _overrideTextScale(double textScale) async {
    await widget.controller.setTextScale(textScale);
    if (mounted && _sliderTextScale == textScale) {
      setState(() => _sliderTextScale = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.enabled;
    return ValueListenableBuilder<double?>(
      valueListenable: widget.controller.textScale,
      builder: (context, appTextScale, _) {
        final textScale = _sliderTextScale ?? appTextScale;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _AccessibilityPanelLabel(
                    label: 'Text Scale',
                    description: 'Scale the system font size.',
                  ),
                ),
                Text(
                  // 1.0 is an override too, so the text scale of the platform
                  // is shown by name rather than as a factor.
                  textScale == null
                      ? 'System default'
                      : '${textScale.toStringAsFixed(2)}x',
                  style: theme.boldTextStyle,
                ),
                const SizedBox(width: denseSpacing),
                DevToolsButton.iconOnly(
                  icon: Icons.restart_alt,
                  outlined: false,
                  tooltip: 'Use the system text scale',
                  onPressed: enabled && appTextScale != null
                      ? () => unawaited(widget.controller.setTextScale(null))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: densePadding),
            Slider(
              value: (textScale ?? 1.0).clamp(_minTextScale, _maxTextScale),
              min: _minTextScale,
              max: _maxTextScale,
              divisions: _textScaleDivisions,
              onChanged: enabled
                  ? (value) => setState(() => _sliderTextScale = value)
                  : null,
              onChangeEnd: enabled
                  ? (value) => unawaited(_overrideTextScale(value))
                  : null,
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
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;

  /// Whether the app has this override on.
  final ValueListenable<bool> value;

  /// Called when the user toggles the switch, or null to disable the switch.
  final ValueChanged<bool>? onChanged;

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
        ValueListenableBuilder<bool>(
          valueListenable: value,
          builder: (context, isOn, _) =>
              DevToolsSwitch(value: isOn, onChanged: onChanged),
        ),
      ],
    );
  }
}

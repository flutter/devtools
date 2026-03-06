// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import 'accessibility_controller.dart';

class AccessibilityControls extends StatelessWidget {
  const AccessibilityControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AreaPaneHeader(title: Text('Settings & Controls')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(defaultSpacing),
            children: const [
              _SystemSimulationControls(),
              SizedBox(height: defaultSpacing),
              _AuditControls(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SystemSimulationControls extends StatelessWidget {
  const _SystemSimulationControls();

  @override
  Widget build(BuildContext context) {
    final controller = screenControllers.lookup<AccessibilityController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SYSTEM SIMULATION',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.highContrastEnabled,
          builder: (context, enabled, _) {
            return SwitchListTile(
              title: const Text('High Contrast Mode'),
              value: enabled,
              onChanged: (value) => controller.toggleHighContrast(value),
            );
          },
        ),
        const SizedBox(height: denseSpacing),
        ValueListenableBuilder<double>(
          valueListenable: controller.textScaleFactor,
          builder: (context, factor, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Text Scale Factor: ${factor.toStringAsFixed(1)}x'),
                Slider(
                  value: factor,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  label: factor.toStringAsFixed(1),
                  onChanged: (value) => controller.setTextScaleFactor(value),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AuditControls extends StatelessWidget {
  const _AuditControls();

  @override
  Widget build(BuildContext context) {
    final controller = screenControllers.lookup<AccessibilityController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AUDIT CONTROLS', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: denseSpacing),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run Audit'),
            onPressed: () => controller.runAudit(),
          ),
        ),
        const SizedBox(height: denseSpacing),
        ValueListenableBuilder<bool>(
          valueListenable: controller.autoAuditEnabled,
          builder: (context, enabled, _) {
            return SwitchListTile(
              title: const Text('Auto-run Audit'),
              value: enabled,
              onChanged: (value) => controller.toggleAutoAudit(value),
            );
          },
        ),
      ],
    );
  }
}

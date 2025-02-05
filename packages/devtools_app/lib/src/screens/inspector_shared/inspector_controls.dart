// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../service/service_extension_widgets.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/feature_flags.dart';
import '../../shared/globals.dart';
import '../../shared/ui/common_widgets.dart';
import '../inspector_shared/inspector_settings_dialog.dart';
import '../inspector_v2/inspector_controller.dart' as v2;

/// Control buttons for the inspector panel.
class InspectorControls extends StatelessWidget {
  const InspectorControls({super.key, this.controller});

  final v2.InspectorController? controller;

  static const minScreenWidthForTextBeforeTruncating = 800.0;
  static const minScreenWidthForTextBeforeScaling = 550.0;

  @override
  Widget build(BuildContext context) {
    final activeButtonColor =
        Theme.of(context).colorScheme.activeToggleButtonColor;
    final isInspectorV2 = controller != null && FeatureFlags.inspectorV2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: serviceConnection
              .serviceManager
              .serviceExtensionManager
              .hasServiceExtension(extensions.toggleSelectWidgetMode.extension),
          builder: (_, selectModeSupported, _) {
            return ServiceExtensionButtonGroup(
              fillColor: activeButtonColor,
              extensions: [
                selectModeSupported
                    ? extensions.toggleSelectWidgetMode
                    : extensions.toggleOnDeviceWidgetInspector,
              ],
              minScreenWidthForTextBeforeScaling:
                  minScreenWidthForTextBeforeScaling,
              minScreenWidthForTextBeforeTruncating:
                  isInspectorV2 ? minScreenWidthForTextBeforeTruncating : null,
            );
          },
        ),
        if (isInspectorV2) ...[
          const SizedBox(width: defaultSpacing),
          ShowImplementationWidgetsButton(controller: controller!),
        ],
        const Spacer(),
        const SizedBox(width: defaultSpacing),
        const InspectorServiceExtensionButtonGroup(),
      ],
    );
  }
}

/// Group of service extension buttons for the inspector panel that control the
/// overlays painted on the connected app.
class InspectorServiceExtensionButtonGroup extends StatelessWidget {
  const InspectorServiceExtensionButtonGroup({super.key});

  static const serviceExtensionButtonsIncludeTextWidth = 1300.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ServiceExtensionButtonGroup(
          fillColor: Theme.of(context).colorScheme.activeToggleButtonColor,
          minScreenWidthForTextBeforeScaling:
              serviceExtensionButtonsIncludeTextWidth,
          extensions: [
            extensions.slowAnimations,
            extensions.debugPaint,
            extensions.debugPaintBaselines,
            extensions.repaintRainbow,
            extensions.invertOversizedImages,
          ],
        ),
        const SizedBox(width: defaultSpacing),
        SettingsOutlinedButton(
          gaScreen: gac.inspector,
          gaSelection: gac.inspectorSettings,
          tooltip: 'Flutter Inspector Settings',
          onPressed: () {
            unawaited(
              showDialog(
                context: context,
                builder: (context) => const FlutterInspectorSettingsDialog(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Toggle button that allows showing/hiding the implementation widgets in the
/// widget tree.
class ShowImplementationWidgetsButton extends StatelessWidget {
  const ShowImplementationWidgetsButton({super.key, required this.controller});

  final v2.InspectorController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.implementationWidgetsHidden,
      builder: (context, isHidden, _) {
        return DevToolsToggleButton(
          fillColor: Theme.of(context).colorScheme.activeToggleButtonColor,
          isSelected: !isHidden,
          message:
              'Show widgets created by the Flutter framework or other packages.',
          label:
              isScreenWiderThan(
                    context,
                    InspectorControls.minScreenWidthForTextBeforeTruncating,
                  )
                  ? 'Show Implementation Widgets'
                  : 'Show',
          onPressed: controller.toggleImplementationWidgetsVisibility,
          icon: Icons.code,
          minScreenWidthForTextBeforeScaling:
              InspectorControls.minScreenWidthForTextBeforeScaling,
        );
      },
    );
  }
}

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../service/service_extension_widgets.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import 'inspector_controller.dart';
import 'inspector_screen.dart';

/// Control buttons for the inspector panel.
class InspectorControls extends StatelessWidget {
  const InspectorControls({super.key, required this.controller});

  final InspectorController controller;

  static const serviceExtensionButtonsIncludeTextWidth = 1200.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: serviceConnection
              .serviceManager.serviceExtensionManager
              .hasServiceExtension(
            extensions.toggleSelectWidgetMode.extension,
          ),
          builder: (_, selectModeSupported, __) {
            return ServiceExtensionButtonGroup(
              extensions: [
                selectModeSupported
                    ? extensions.toggleSelectWidgetMode
                    : extensions.toggleOnDeviceWidgetInspector,
              ],
              minScreenWidthForTextBeforeScaling:
                  InspectorScreenBodyState.minScreenWidthForTextBeforeScaling,
            );
          },
        ),
        const SizedBox(width: defaultSpacing),
        ShowImplementationWidgetsButton(controller: controller),
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

  static const serviceExtensionButtonsIncludeTextWidth = 1200.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ServiceExtensionButtonGroup(
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
  const ShowImplementationWidgetsButton({
    super.key,
    required this.controller,
  });

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.implementationWidgetsHidden,
      builder: (context, isHidden, _) {
        return DevToolsToggleButton(
          isSelected: !isHidden,
          message:
              'Show widgets created by the Flutter framework or other packages.',
          label: 'Show Implementation Widgets',
          onPressed: controller.toggleImplementationWidgetsVisibility,
          icon: Icons.code,
          minScreenWidthForTextBeforeScaling:
              InspectorScreenBodyState.minScreenWidthForTextBeforeScaling,
        );
      },
    );
  }
}

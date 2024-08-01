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

class InspectorControls extends StatelessWidget {
  const InspectorControls({
    super.key,
    required this.controller,
  });

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
        const Spacer(),
        HideImplementationWidgetsButton(controller: controller),
        const SizedBox(width: defaultSpacing),
        const ServiceExtensionButtonsGroup(),
      ],
    );
  }
}

class ServiceExtensionButtonsGroup extends StatelessWidget {
  const ServiceExtensionButtonsGroup({
    super.key,
  });

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
        // TODO(jacobr): implement TogglePlatformSelector.
        //  TogglePlatformSelector().selector
      ],
    );
  }
}

class HideImplementationWidgetsButton extends StatelessWidget {
  const HideImplementationWidgetsButton({
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
          isSelected: isHidden,
          message:
              'Hide widgets created by the Flutter framework or other packages.',
          label: 'Hide Implementation Widgets',
          onPressed: () async {
            await controller.toggleImplementationWidgetsVisibility();
          },
          icon: Icons.code_off,
        );
      },
    );
  }
}

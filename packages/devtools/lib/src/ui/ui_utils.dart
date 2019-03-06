// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import 'package:meta/meta.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../service_extensions.dart';
import '../service_registrations.dart';
import '../service_registrations.dart' as registrations;
import '../utils.dart';
import 'elements.dart';
import 'environment.dart' as environment;
import 'fake_flutter/dart_ui/dart_ui.dart';
import 'html_icon_renderer.dart';
import 'material_icons.dart';
import 'primer.dart';

const int defaultSplitterWidth = 10;

CoreElement createExtensionCheckBox(
    ToggleableServiceExtensionDescription extensionDescription) {
  final extensionName = extensionDescription.extension;
  final CoreElement input = checkbox();

  serviceManager.serviceExtensionManager.hasServiceExtension(
      extensionName, (available) => input.disabled = !available);

  serviceManager.serviceExtensionManager.getServiceExtensionState(
    extensionName,
    (state) {
      final html.InputElement e = input.element;
      e.checked = state.value;
    },
  );

  input.element.onChange.listen((_) {
    final html.InputElement e = input.element;
    serviceManager.serviceExtensionManager
        .setServiceExtensionState(extensionName, e.checked, e.checked);
  });
  final inputLabel = label();
  if (extensionDescription.icon != null) {
    inputLabel.add(createIconElement(extensionDescription.icon));
  }
  inputLabel.add(span(text: extensionName));

  final outerDiv = div(c: 'form-checkbox')
    ..add(CoreElement('label')..add([input, inputLabel]));
  input.setAttribute('title', extensionDescription.disabledTooltip);
  return outerDiv;
}

List<CoreElement> getServiceExtensionButtons() {
  return [
    div(c: 'btn-group collapsible')
      ..add(<CoreElement>[
        ServiceExtensionButton(performanceOverlay).button,
        ServiceExtensionButton(togglePlatformMode).button,
      ]),
    div(c: 'btn-group collapsible margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(debugPaint).button,
        ServiceExtensionButton(debugPaintBaselines).button,
      ]),
    div(c: 'btn-group collapsible margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(slowAnimations).button,
      ]),
    div(c: 'btn-group collapsible overflow margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(repaintRainbow).button,
        ServiceExtensionButton(debugAllowBanner).button,
      ]),
  ];
}

StatusItem createLinkStatusItem(
  String text, {
  @required String href,
  @required String title,
}) {
  // TODO(jacobr): cleanup icon rendering so the icon changes color on hover.
  final icon = createIconElement(const MaterialIcon(
    'open_in_new',
    Colors.black45,
  ));
  // TODO(jacobr): add this style to the css for all icons displayed as HTML
  // once we verify there are not unintended consequences.
  icon.element.style
    ..verticalAlign = 'text-bottom'
    ..marginBottom = '0';
  final element = CoreElement('a')
    ..add(<CoreElement>[icon, span(text: text)])
    ..setAttribute('href', href)
    ..setAttribute('target', '_blank')
    ..element.title = title;
  return StatusItem()..element.add(element);
}

CoreElement createHotReloadRestartGroup(Framework framework) {
  return div(c: 'btn-group')
    ..add([
      createHotReloadButton(framework),
      createHotRestartButton(framework),
    ]);
}

CoreElement createHotReloadButton(Framework framework) {
  final action = () async {
    await serviceManager.performHotReload();
  };
  final errorAction = (e) {
    framework.showError('Error performing hot reload', e);
  };
  return RegisteredServiceExtensionButton(
    registrations.hotReload,
    action,
    errorAction,
  ).button;
}

// TODO: move this button out of timeline if we decide to make a global button bar.
CoreElement createHotRestartButton(Framework framework) {
  final action = () async {
    await serviceManager.performHotRestart();
  };
  final errorAction = (e) {
    framework.showError('Error performing hot restart', e);
  };

  return RegisteredServiceExtensionButton(
    registrations.hotRestart,
    action,
    errorAction,
  ).button;
}

/// Button that calls a service extension. Service extensions can be found in
/// [service_extensions.dart].
class ServiceExtensionButton {
  ServiceExtensionButton(this.extensionDescription) {
    button = PButton.icon(
      extensionDescription.description,
      extensionDescription.icon,
      title: extensionDescription.disabledTooltip,
    )..small();

    final extensionName = extensionDescription.extension;

    // Disable button for unavailable service extensions.
    button.disabled = !serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensionName);
    serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName, (available) => button.disabled = !available);

    button.click(() => _click());

    _updateState();
  }

  final ToggleableServiceExtensionDescription extensionDescription;
  PButton button;

  void _click() {
    final bool wasSelected = button.element.classes.contains('selected');
    serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensionDescription.extension,
      !wasSelected,
      wasSelected
          ? extensionDescription.disabledValue
          : extensionDescription.enabledValue,
    );
  }

  void _updateState() {
    // Select button whose state is already enabled.
    serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensionDescription.extension, (state) {
      final extensionEnabled = state.value == extensionDescription.enabledValue;
      button.toggleClass('selected', extensionEnabled);
      button.tooltip = extensionEnabled
          ? extensionDescription.enabledTooltip
          : extensionDescription.disabledTooltip;
    });
  }
}

/// Button that calls a registered service from flutter_tools. Registered
/// services can be found in [service_registrations.dart].
class RegisteredServiceExtensionButton {
  RegisteredServiceExtensionButton(
    this.serviceDescription,
    this.action,
    this.errorAction,
  ) {
    button = PButton.icon(
      serviceDescription.title,
      serviceDescription.icon,
      title: serviceDescription.title,
    )
      ..small()
      ..hidden(true);

    // Only show the button if the device supports the given service.
    serviceManager.hasRegisteredService(
      serviceDescription.service,
      (registered) {
        button.hidden(!registered);
      },
    );

    button.click(() => _click());
  }

  final RegisteredServiceDescription serviceDescription;
  final VoidAsyncFunction action;
  final VoidFunctionWithArg errorAction;
  PButton button;

  void _click() async {
    try {
      button.disabled = true;
      await action();
    } catch (e) {
      errorAction(e);
    } finally {
      button.disabled = false;
    }
  }
}

bool shouldDisableTab(String key) {
  final queryString = html.window.location.search;
  if (queryString == null || queryString.length <= 1) {
    return false;
  }

  final qsParams = Uri.splitQueryString(queryString.substring(1));
  return qsParams['hide']?.split(',')?.contains(key) ?? false;
}

/// Creates a canvas scaled to match the device's devicePixelRatio.
///
/// A default canvas will look pixelated on high devicePixelRatio screens so it
/// is important to scale the canvas to reflect the devices physical pixels
/// instead of logical pixels.
///
/// There are some complicated edge cases for non-integer devicePixelRatios as
/// found on Windows 10 so always use this method instead of rolling your own.
html.CanvasElement createHighDpiCanvas(int width, int height) {
  // If the size has to be rounded, we choose to err towards a higher resolution
  // image instead of a lower resolution one. The cost of a higher resolution
  // image is generally only slightly higher memory usage while a lower
  // resolution image could introduce rendering artifacts.
  final int scaledWidth = (width * environment.devicePixelRatio).ceil();
  final int scaledHeight = (height * environment.devicePixelRatio).ceil();
  final canvas = html.CanvasElement(width: scaledWidth, height: scaledHeight);
  canvas.style
    ..width = '${width}px'
    ..height = '${height}px';
  final context = canvas.context2D;

  // If there is rounding error as in the case of a non-integer DPI as on some
  // Windows 10 machines, the ratio between the Canvas's dimensions and its size
  // won't precisely match environment.devicePixelRatio.
  // We fix this issue by applying a scale transform to the canvas to reflect
  // the actual ratio between the canvas size and logical pixels in each axis.
  context.scale(scaledWidth / width, scaledHeight / height);
  return canvas;
}

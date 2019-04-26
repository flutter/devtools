// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:devtools/devtools.dart' as devtools show version;
import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../eval_on_dart_library.dart';
import '../framework/framework.dart';
import '../globals.dart';
import '../service_extensions.dart';
import '../service_registrations.dart';
import '../service_registrations.dart' as registrations;
import '../utils.dart';
import 'analytics.dart' as ga;
import 'elements.dart';
import 'environment.dart' as environment;
import 'fake_flutter/dart_ui/dart_ui.dart';
import 'html_icon_renderer.dart';
import 'material_icons.dart';
import 'primer.dart';

const int defaultSplitterWidth = 10;
const String runInProfileModeDocsUrl =
    'https://flutter.dev/docs/testing/ui-performance#run-in-profile-mode';

// GA dimensions:
String userAppType = ''; // dimension1
String userBuildType = ''; // dimension2
String userPlatformType = ''; // dimension3

String devtoolsPlatformType = ''; // dimension4 MacIntel/Linux/Windows/Android_n
String devtoolsChrome = ''; // dimension5 Chrome/n.n.n  or Crios/n.n.n
const String devtoolsVersion = devtools.version; //dimension6 n.n.n

bool get isDimensionsComputed =>
    (userAppType.length +
        userBuildType.length +
        userPlatformType.length +
        devtoolsPlatformType.length +
        devtoolsChrome.length) >
    0;

/// Computes the DevTools application. Fills in the devtoolsPlatformType and
/// devtoolsChrome.
void computeDevToolsState() {
  // Platform
  final String platform = html.window.navigator.platform;
  platform.replaceAll(' ', '_');
  devtoolsPlatformType = platform;

  final String appVersion = html.window.navigator.appVersion;
  final List<String> splits = appVersion.split(' ');
  final len = splits.length;
  for (int index = 0; index < len; index++) {
    final String value = splits[index];
    // Chrome or Chrome iOS
    if (value.startsWith(ga.devToolsChrome) ||
        value.startsWith(ga.devToolsChromeIos)) {
      devtoolsChrome = value;
    } else if (value.startsWith('Android')) {
      // appVersion for Android is 'Android n.n.n'
      devtoolsPlatformType =
          '${ga.devToolsPlatformTypeAndroid}${splits[index + 1]}';
    }
  }
}

// Computes the running application.
void computeApplicationState() async {
  final isFlutter = await serviceManager.connectedApp.isFlutterApp;
  final isWebApp = await serviceManager.connectedApp.isFlutterWebApp;
  final isProfile = await serviceManager.connectedApp.isProfileBuild;
  final isAnyFlutterApp = await serviceManager.connectedApp.isAnyFlutterApp;

  if (isDimensionsComputed) return;

  if (isFlutter) {
    // Compute the Flutter platform for the user's running application.
    final VmService vmService = serviceManager.service;
    final io = EvalOnDartLibrary(['dart:io'], vmService);

    // eval user's Platform for all possible values.
    final android = await io.eval('Platform.isAndroid', isAlive: null);
    final iOS = await io.eval('Platform.isIOS', isAlive: null);
    final fuchsia = await io.eval('Platform.isFuchsia', isAlive: null);
    final linux = await io.eval('Platform.isLinux', isAlive: null);
    final macOS = await io.eval('Platform.isMacOS', isAlive: null);
    final windows = await io.eval('Platform.isWindows', isAlive: null);

    if (android.valueAsString == 'true')
      userPlatformType = ga.platformTypeAndroid;
    else if (iOS.valueAsString == 'true')
      userPlatformType = ga.platformTypeIOS;
    else if (fuchsia.valueAsString == 'true')
      userPlatformType = ga.platformTypeFuchsia;
    else if (linux.valueAsString == 'true')
      userPlatformType = ga.platformTypeLinux;
    else if (macOS.valueAsString == 'true')
      userPlatformType = ga.platformTypeMac;
    else if (windows.valueAsString == 'true')
      userPlatformType = ga.platformTypeWindows;
  }

  if (isAnyFlutterApp) {
    if (isFlutter) userAppType = ga.appTypeFlutter;
    if (isWebApp) userAppType = ga.appTypeWeb;
  }
  userBuildType = isProfile ? ga.buildTypeProfile : ga.buildTypeDebug;

  computeDevToolsState();
}

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
    div(c: 'btn-group collapsible-1200 nowrap margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(performanceOverlay).button,
        ServiceExtensionButton(togglePlatformMode).button,
      ]),
    div(c: 'btn-group collapsible-1200 nowrap margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(debugPaint).button,
        ServiceExtensionButton(debugPaintBaselines).button,
      ]),
    div(c: 'btn-group collapsible-1200 nowrap margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(slowAnimations).button,
      ]),
    div(c: 'btn-group collapsible-1400 nowrap margin-left')
      ..add(<CoreElement>[
        ServiceExtensionButton(repaintRainbow).button,
        ServiceExtensionButton(debugAllowBanner).button,
      ]),
  ];
}

StatusItem createLinkStatusItem(
  CoreElement textElement, {
  @required String href,
  @required String title,
}) {
  // TODO(jacobr): cleanup icon rendering so the icon changes color on hover.
  final icon = createIconElement(const MaterialIcon(
    'open_in_new',
    Colors.grey,
  ));
  // TODO(jacobr): add this style to the css for all icons displayed as HTML
  // once we verify there are not unintended consequences.
  icon.element.style
    ..verticalAlign = 'text-bottom'
    ..marginBottom = '0';
  final element = CoreElement('a')
    ..add(<CoreElement>[icon, textElement])
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

Future<void> maybeShowDebugWarning(Framework framework) async {
  if (!await serviceManager.connectedApp.isProfileBuild) {
    framework.showWarning(children: <CoreElement>[
      div(
          text: 'You are running your app in debug mode. Debug mode frame '
              'rendering times are not indicative of release performance.'),
      div()
        ..add(span(
            text:
                '''Relaunch your application with the '--profile' argument, or '''))
        ..add(a(
            text: 'relaunch in profile mode from VS Code or IntelliJ',
            href: runInProfileModeDocsUrl,
            target: '_blank;'))
        ..add(span(text: '.')),
    ]);
  }
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
    switch (extensionDescription.extension) {
      case 'ext.flutter.debugAllowBanner':
        ga.select(ga.inspector, ga.debugBanner);
        break;
      case 'ext.flutter.debugPaint':
        ga.select(ga.inspector, ga.debugPaint);
        break;
      case 'ext.flutter.debugPaintBaselinesEnabled':
        ga.select(ga.inspector, ga.paintBaseline);
        break;
      case 'ext.flutter.showPerformanceOverlay':
        ga.select(ga.inspector, ga.performanceOverlay);
        break;
      case 'ext.flutter.profileWidgetBuilds':
        ga.select(ga.inspector, ga.trackRebuilds);
        break;
      case 'ext.flutter.repaintRainbow':
        ga.select(ga.inspector, ga.repaintRainbow);
        break;
      case 'ext.flutter.timeDilation':
        ga.select(ga.inspector, ga.slowAnimation);
        break;
      case 'ext.flutter.platformOverride':
        ga.select(ga.inspector, ga.iOS);
        break;
      case 'ext.flutter.inspector.show':
        ga.select(ga.inspector, ga.selectWidgetMode);
        break;
    }

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

Set<String> _hiddenPages;

Set<String> get hiddenPages {
  return _hiddenPages ??= _lookupHiddenPages();
}

Set<String> _lookupHiddenPages() {
  final queryString = html.window.location.search;
  if (queryString == null || queryString.length <= 1) {
    // TODO(dantup): Remove this ignore, change to `{}` and bump SDK requirements
    // in pubspec.yaml (devtools + devtools_server) once Flutter stable includes
    // Dart SDK >= v2.2.
    // ignore: prefer_collection_literals
    return Set();
  }
  final qsParams = Uri.splitQueryString(queryString.substring(1));
  return (qsParams['hide'] ?? '').split(',').toSet();
}

bool isTabDisabledByQuery(String key) => hiddenPages.contains(key);

bool get allTabsEnabledByQuery => hiddenPages.contains('none');

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

void downloadFile(String src, String filename) {
  final element = html.document.createElement('a');
  element.setAttribute('href', html.Url.createObjectUrl(html.Blob([src])));
  element.setAttribute('download', filename);
  element.style.display = 'none';
  html.document.body.append(element);
  element.click();
  element.remove();
}

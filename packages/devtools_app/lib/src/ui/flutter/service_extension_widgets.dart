// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../service_extensions.dart';
/* Dead imports to uncomment when the rest of the file is ported.
import '../../service_manager.dart' show ServiceExtensionState;
import '../../service_registrations.dart';
import '../../utils.dart';
*/

// TODO(jacobr): add support for analytics.
//import '../analytics.dart' as ga;
import '../../service_registrations.dart';
import '../../utils.dart';
import 'flutter_icon_renderer.dart';

class ServiceExtensionButtonGroup extends StatefulWidget {
  const ServiceExtensionButtonGroup({
    this.minIncludeLabelWidth,
    @required this.extensions,
  });

  final double minIncludeLabelWidth;
  final List<ToggleableServiceExtensionDescription> extensions;

  @override
  _ServiceExtensionButtonGroupState createState() =>
      _ServiceExtensionButtonGroupState();
}

/// Data class tracking the state of a single service extension.
class ExtensionState {
  ExtensionState(this.description);

  final ToggleableServiceExtensionDescription description;
  bool isSelected = false;
  bool isAvailable = false;
  StreamSubscription subscription;

  void dispose() {
    subscription?.cancel();
    subscription = null;
  }
}

class _ServiceExtensionButtonGroupState
    extends State<ServiceExtensionButtonGroup> {
  List<ExtensionState> _extensionStates;

  @override
  void initState() {
    super.initState();
    _extensionStates = widget.extensions
        .map((extension) => ExtensionState(extension))
        .toList();
    for (var extension in _extensionStates) {
      final extensionName = extension.description.extension;
      serviceManager.serviceExtensionManager
          .getServiceExtensionState(extensionName, (state) {
        setState(() {
          extension.isSelected =
              state.value == extension.description.enabledValue;
        });
      });
      extension.isAvailable = serviceManager.serviceExtensionManager
          .isServiceExtensionAvailable(extensionName);

      extension.subscription =
          serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName,
        (available) {
          setState(() {
            extension.isAvailable = available;
          });
        },
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    for (var config in _extensionStates) {
      config.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): respect the minSize animating to hidden when the minSize
    // for the window is not met.
    // TODO(jacobr): respect _available better by displaying whether individual
    // widgets are available.
    final available = _extensionStates.any((e) => e.isAvailable);
    // TODO(jacobr): animate showing and hiding the labels.
    final showLabels = widget.minIncludeLabelWidth == null ||
        MediaQuery.of(context).size.width >= widget.minIncludeLabelWidth;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ToggleButtons(
        constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
        children: <Widget>[
          for (var extensionState in _extensionStates)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(children: [
                getIconWidget(extensionState.description.icon),
                if (showLabels)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(extensionState.description.description),
                  )
              ]),
            )
        ],
        isSelected: [for (var e in _extensionStates) e.isSelected],
        onPressed: available
            ? (index) {
                final extensionState = _extensionStates[index];
                if (extensionState.isAvailable) {
                  setState(() {
                    final wasSelected = extensionState.isSelected;
                    // TODO(jacobr): support analytics.
                    // ga.select(extensionDescription.gaScreenName, extensionDescription.gaItem);

                    serviceManager.serviceExtensionManager
                        .setServiceExtensionState(
                      extensionState.description.extension,
                      !wasSelected,
                      wasSelected
                          ? extensionState.description.disabledValue
                          : extensionState.description.enabledValue,
                    );
                  });
                } else {
                  // TODO(jacobr): display a toast warning that the extension is
                  // not available. That could happen as entire groups have to
                  // be enabled or disabled at a time.
                }
              }
            : null,
      ),
    );
  }
}

List<Widget> getServiceExtensionWidgets() {
  return [
    ServiceExtensionButtonGroup(
      minIncludeLabelWidth: 1200,
      extensions: [performanceOverlay, slowAnimations],
    ),
    ServiceExtensionButtonGroup(
      minIncludeLabelWidth: 1200,
      extensions: [debugPaint, debugPaintBaselines],
    ),
    ServiceExtensionButtonGroup(
      minIncludeLabelWidth: 1400,
      extensions: [repaintRainbow, debugAllowBanner],
    ),
    // XXX TODO(jacobr): implement.
    //  TogglePlatformSelector().selector
  ];
}

// TODO(jacobr): use this button to support hot reload.
// It appears the matching class in service_extension_elements is not being
// used but that is likely accidental.
class RegisteredServiceExtensionButton extends StatefulWidget {
  const RegisteredServiceExtensionButton(
    this.serviceDescription,
    this.action,
    this.errorAction, {
    this.showTitle = false,
  });

  final RegisteredServiceDescription serviceDescription;
  final VoidAsyncFunction action;
  final VoidFunctionWithArg errorAction;
  final bool showTitle;

  @override
  _RegisteredServiceExtensionButtonState createState() =>
      _RegisteredServiceExtensionButtonState();
}

class _RegisteredServiceExtensionButtonState
    extends State<RegisteredServiceExtensionButton> {
  StreamSubscription<bool> _subscription;

  bool _disabled = false;
  bool _hidden = true;
  @override
  void initState() {
    super.initState();
    // Only show the button if the device supports the given service.
    _subscription = serviceManager.hasRegisteredService(
      widget.serviceDescription.service,
      (registered) {
        setState(() {
          _hidden = !registered;
        });
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _subscription.cancel();
  }

  void _click() async {
    try {
      setState(() {
        _disabled = true;
      });
      await widget.action();
    } catch (e) {
      widget.errorAction(e);
    } finally {
      setState(() {
        _disabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return Container();

    return FlatButton(
      onPressed: _disabled ? null : _click,
      child: Row(children: [
        getIconWidget(widget.serviceDescription.icon),
        if (widget.showTitle)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(widget.serviceDescription.title),
          ),
      ]),
    );
  }
}

// TODO(jacobr): port these classes to Flutter.
/*
/// Checkbox that stays synced with the value of a service extension.
///
/// Service extensions can be found in [service_extensions.dart].
///
/// See also:
/// * ServiceExtensionWidget, which provides the same functionality but uses
///   a button instead of a button. In general, using a button makes the UI
///   more compact but the checkbox makes the current state of the UI clearer.
class ServiceExtensionCheckbox {
  ServiceExtensionCheckbox(this.extensionDescription)
      : element = CoreElement('label') {
    final checkbox = CoreElement('input')
      ..setAttribute('type', 'checkbox');
    _checkboxElement = checkbox.element;

    element.add(<CoreElement>[
      checkbox,
      span(text: ' ${extensionDescription.description}'),
    ]);

    final extensionName = extensionDescription.extension;

    // Disable button for unavailable service extensions.
    checkbox.disabled = !serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensionName);
    serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName, (available) => checkbox.disabled = !available);

    _checkboxElement.onChange.listen((_) {
      ga.select(extensionDescription.gaScreenName, extensionDescription.gaItem);

      final bool selected = _checkboxElement.checked;
      serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionDescription.extension,
        selected,
        selected
            ? extensionDescription.enabledValue
            : extensionDescription.disabledValue,
      );
    });
    _updateState();
  }

  final ToggleableServiceExtensionDescription extensionDescription;
  final CoreElement element;
  html.InputElement _checkboxElement;

  void _updateState() {
    serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensionDescription.extension, (state) {
      final extensionEnabled = state.value == extensionDescription.enabledValue;
      _checkboxElement.checked = extensionEnabled;
      // We display the tooltips in the reverse order they show up in
      // ServiceExtensionWidget as for a checkbox it makes more sense to show
      // a tooltip for the current value instead of for the value clicking on
      // the button would switch to.
      element.tooltip = extensionEnabled
          ? extensionDescription.disabledTooltip
          : extensionDescription.enabledTooltip;
    });
  }
}

/// Dropdown selector that calls a service extension.
///
/// Service extensions can be found in [service_extensions.dart].
class ServiceExtensionSelector {
  ServiceExtensionSelector(this.extensionDescription) : selector = PSelect() {
    selector
      ..small()
      ..clazz('button-bar-dropdown')
      ..change(_handleSelect)
      ..tooltip = extensionDescription.tooltips.first ??
          extensionDescription.description;

    final extensionName = extensionDescription.extension;

    // Disable selector for unavailable service extensions.
    selector.disabled = !serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensionName);
    serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName, (available) => selector.disabled = !available);

    addOptions();
    updateState();
  }

  final ServiceExtensionDescription extensionDescription;

  final PSelect selector;

  String _selectedValue;

  void _handleSelect() {
    if (selector.value == _selectedValue) return;

    ga.select(extensionDescription.gaScreenName, extensionDescription.gaItem);

    final extensionValue = extensionDescription
        .values[extensionDescription.displayValues.indexOf(selector.value)];

    serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensionDescription.extension,
      true,
      extensionValue,
    );

    _selectedValue = selector.value;
  }

  void addOptions() {
    extensionDescription.displayValues.forEach(selector.option);
  }

  void updateState() {
    // Select option whose state is already enabled.
    serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensionDescription.extension, (state) {
      updateSelection(state);
    });
  }

  void updateSelection(ServiceExtensionState state) {
    if (state.value != null) {
      final selectedIndex = extensionDescription.values.indexOf(state.value);
      selector.selectedIndex = selectedIndex;
      _selectedValue = extensionDescription.displayValues[selectedIndex];
    }
  }
}

class TogglePlatformSelector extends ServiceExtensionSelector {
  TogglePlatformSelector() : super(togglePlatformMode);

  static const fuchsia = 'Fuchsia';

  @override
  void addOptions() {
    extensionDescription.displayValues
        .where((displayValue) => !displayValue.contains(fuchsia))
        .forEach(selector.option);
  }

  @override
  void updateState() {
    // Select option whose state is already enabled.
    serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensionDescription.extension, (state) {
      if (state.value == fuchsia.toLowerCase()) {
        selector.option(extensionDescription.displayValues
            .firstWhere((displayValue) => displayValue.contains(fuchsia)));
      }
      updateSelection(state);
    });
  }
}

 */

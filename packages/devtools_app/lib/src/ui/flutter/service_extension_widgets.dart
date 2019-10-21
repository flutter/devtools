// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../globals.dart';
import '../../service_extensions.dart';
import '../../service_registrations.dart';
import '../../utils.dart';
import 'flutter_icon_renderer.dart';
import 'label.dart';

/// Group of buttons where each button toggles the state of a VMService
/// extension.
///
/// Use this class any time you need to write UI code that exposes button(s) to
/// control VMServiceExtension. This class handles error handling and lifecycle
/// states for keeping state on the client and device consistent so you don't
/// have to.
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
}

class _ServiceExtensionButtonGroupState
    extends State<ServiceExtensionButtonGroup> with AutoDisposeMixin {
  List<ExtensionState> _extensionStates;

  @override
  void initState() {
    super.initState();
    // To use ToggleButtons we have to track states for all buttons in the
    // group here rather than tracking state with the individual button widgets
    // which would be more natural.

    _extensionStates = [for (var e in widget.extensions) ExtensionState(e)];

    for (var extension in _extensionStates) {
      // Listen for changes to the state of each service extension using the
      // VMServiceManager.
      final extensionName = extension.description.extension;
      // Update the button state to match the latest state on the VM.
      autoDispose(serviceManager.serviceExtensionManager
          .getServiceExtensionState(extensionName, (state) {
        setState(() {
          extension.isSelected =
              state.value == extension.description.enabledValue;
        });
      }));
      // Track whether the extension is actually exposed by the VM.
      autoDispose(serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName,
        (available) {
          setState(() {
            extension.isAvailable = available;
          });
        },
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): respect _available better by displaying whether individual
    // widgets are available (not currently supported by ToggleButtons).
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
            _buildExtension(extensionState, showLabels)
        ],
        isSelected: [for (var e in _extensionStates) e.isSelected],
        onPressed: available ? _onPressed : null,
      ),
    );
  }

  Widget _buildExtension(ExtensionState extensionState, bool showText) {
    return Label(
      extensionState.description.icon,
      extensionState.description.description,
      showText: showText,
    );
  }

  void _onPressed(int index) {
    final extensionState = _extensionStates[index];
    if (extensionState.isAvailable) {
      setState(() {
        final wasSelected = extensionState.isSelected;
        // TODO(jacobr): support analytics.
        // ga.select(extensionDescription.gaScreenName, extensionDescription.gaItem);

        serviceManager.serviceExtensionManager.setServiceExtensionState(
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
    // TODO(jacobr): implement TogglePlatformSelector.
    //  TogglePlatformSelector().selector
  ];
}

/// Class to use for a button that when clicked invokes a VM Service such as
/// hot reload or hot restart.
///
/// Callbacks on when the action is performed or an error occurs are provided
/// to wire up cases such as hot reload where users need to be notified when
/// the action completes.
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
    if (_hidden) return const SizedBox();

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

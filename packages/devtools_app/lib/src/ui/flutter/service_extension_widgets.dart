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
import '../fake_flutter/fake_flutter.dart';
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
    this.minIncludeTextWidth,
    @required this.extensions,
  });

  final double minIncludeTextWidth;
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
    _initExtensionState();
  }

  void _initExtensionState() {
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
  void didUpdateWidget(ServiceExtensionButtonGroup oldWidget) {
    if (!listEquals(oldWidget.extensions, widget.extensions)) {
      cancel();
      _initExtensionState();
      setState(() {});
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): respect _available better by displaying whether individual
    // widgets are available (not currently supported by ToggleButtons).
    final available = _extensionStates.any((e) => e.isAvailable);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ToggleButtons(
        constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
        children: <Widget>[
          for (var extensionState in _extensionStates)
            _buildExtension(extensionState)
        ],
        isSelected: [for (var e in _extensionStates) e.isSelected],
        onPressed: available ? _onPressed : null,
      ),
    );
  }

  Widget _buildExtension(ExtensionState extensionState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Label(
        extensionState.description.icon,
        extensionState.description.description,
        minIncludeTextWidth: widget.minIncludeTextWidth,
      ),
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
      minIncludeTextWidth: 1200,
      extensions: [performanceOverlay, slowAnimations],
    ),
    ServiceExtensionButtonGroup(
      minIncludeTextWidth: 1400,
      extensions: [debugPaint, debugPaintBaselines],
    ),
    ServiceExtensionButtonGroup(
      minIncludeTextWidth: 1600,
      extensions: [repaintRainbow, debugAllowBanner],
    ),
    // TODO(jacobr): implement TogglePlatformSelector.
    //  TogglePlatformSelector().selector
  ];
}

/// Button that performs a hot reload on the [serviceManager].
class HotReloadButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _RegisteredServiceExtensionButton._(
      serviceDescription: hotReload,
      action: () => serviceManager.performHotReload(),
      inProgressText: 'Performing hot reload',
      completedText: 'Hot reload completed',
      describeError: (error) => 'Unable to hot reload the app: $error',
    );
  }
}

/// Button that performs a hot restart on the [serviceManager].
class HotRestartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _RegisteredServiceExtensionButton._(
      serviceDescription: hotRestart,
      action: () => serviceManager.performHotRestart(),
      inProgressText: 'Performing hot restart',
      completedText: 'Hot restart completed',
      describeError: (error) => 'Unable to hot restart the app: $error',
    );
  }
}

/// Button that when clicked invokes a VM Service , such as hot reload or hot
/// restart.
///
/// This button will attempt to register to the given service description,
class _RegisteredServiceExtensionButton extends StatefulWidget {
  const _RegisteredServiceExtensionButton._({
    @required this.serviceDescription,
    @required this.action,
    @required this.inProgressText,
    @required this.completedText,
    @required this.describeError,
  });

  /// The service to subscribe to.
  final RegisteredServiceDescription serviceDescription;

  /// Callback to the method on [serviceManager] to invoke when clicked.
  final VoidAsyncFunction action;

  /// The text to show when the action is in progress.
  ///
  /// This will be shown in a [SnackBar] when completed.
  final String inProgressText;

  /// The text to show when the action is completed.
  ///
  /// This will be shown in a [SnackBar], replacing the [inProgressText].
  final String completedText;

  /// Callback that describes any error that occurs.
  ///
  /// This will replace the [inProgressText] in a [SnackBar].
  final String Function(dynamic error) describeError;

  @override
  _RegisteredServiceExtensionButtonState createState() =>
      _RegisteredServiceExtensionButtonState();
}

class _RegisteredServiceExtensionButtonState
    extends State<_RegisteredServiceExtensionButton> {
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
    if (_disabled) {
      return;
    }
    setState(() {
      _disabled = true;
    });
    // TODO(https://github.com/flutter/devtools/issues/1249): Avoid adding
    // and removing snackbars so often as we do here.
    Scaffold.of(context)
        .removeCurrentSnackBar(reason: SnackBarClosedReason.remove);
    // Push a snackbar that the action is in progress.
    final snackBar = Scaffold.of(context).showSnackBar(
      SnackBar(content: Text(widget.inProgressText)),
    );
    try {
      await widget.action();
      // If the action was successful, remove the snack bar and show a new
      // one with action success.
      snackBar.close();
      Scaffold.of(context).showSnackBar(
        SnackBar(content: Text(widget.completedText)),
      );
    } catch (e) {
      // On a failure, remove the snack bar and replace it with the failure.
      snackBar.close();
      Scaffold.of(context).showSnackBar(
        SnackBar(content: Text(widget.describeError(e))),
      );
    } finally {
      setState(() {
        _disabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox();

    return InkWell(
      onTap: _click,
      child: Container(
        constraints: const BoxConstraints.tightFor(width: 48.0, height: 48.0),
        alignment: Alignment.center,
        // TODO(djshuckerow): Just make these icons the right size to fit this box.
        // The current size is a little tiny by comparison to our other
        // material icons.
        child: getIconWidget(widget.serviceDescription.icon),
      ),
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

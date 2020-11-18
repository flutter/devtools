// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../config_specific/logger/logger.dart';
import '../core/message_bus.dart';
import '../globals.dart';
import '../notifications.dart';
import '../scaffold.dart';
import '../service_extensions.dart';
import '../service_registrations.dart';
import '../theme.dart';
import '../utils.dart';
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
      final state = serviceManager.serviceExtensionManager
          .getServiceExtensionState(extensionName);
      extension.isSelected = state.value.enabled;

      addAutoDisposeListener(state, () {
        setState(() {
          extension.isSelected = state.value.enabled;
        });
      });
      // Track whether the extension is actually exposed by the VM.
      final listenable = serviceManager.serviceExtensionManager
          .hasServiceExtension(extensionName);
      extension.isAvailable = listenable.value;
      addAutoDisposeListener(
        listenable,
        () {
          setState(() {
            extension.isAvailable = listenable.value;
          });
        },
      );
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
    return ToggleButtons(
      constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
      children: <Widget>[
        for (var extensionState in _extensionStates)
          _buildExtension(extensionState)
      ],
      isSelected: [for (var e in _extensionStates) e.isSelected],
      onPressed: available ? _onPressed : null,
    );
  }

  Widget _buildExtension(ExtensionState extensionState) {
    final description = extensionState.description;
    return Tooltip(
      message: extensionState.isSelected
          ? description.enabledTooltip
          : description.disabledTooltip,
      waitDuration: tooltipWait,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
        child: ImageIconLabel(
          description.icon,
          description.description,
          minIncludeTextWidth: widget.minIncludeTextWidth,
        ),
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

/// Button that performs a hot reload on the [serviceManager].
class HotReloadButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO(devoncarew): Show as disabled when reload service calls are in progress.

    return ActionButton(
      tooltip: 'Hot reload',
      child: _RegisteredServiceExtensionButton._(
        serviceDescription: hotReload,
        action: () {
          return serviceManager.runDeviceBusyTask(
            _wrapReloadCall('reload', serviceManager.performHotReload),
          );
        },
        completedText: 'Hot reload completed.',
        describeError: (error) => 'Unable to hot reload the app: $error',
      ),
    );
  }
}

/// Button that performs a hot restart on the [serviceManager].
class HotRestartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO(devoncarew): Show as disabled when reload service calls are in progress.

    return ActionButton(
      tooltip: 'Hot restart',
      child: _RegisteredServiceExtensionButton._(
        serviceDescription: hotRestart,
        action: () {
          return serviceManager.runDeviceBusyTask(
            _wrapReloadCall('restart', serviceManager.performHotRestart),
          );
        },
        completedText: 'Hot restart completed.',
        describeError: (error) => 'Unable to hot restart the app: $error',
      ),
    );
  }
}

Future<void> _wrapReloadCall(
  String name,
  Future<void> Function() reloadCall,
) async {
  try {
    final Stopwatch timer = Stopwatch()..start();
    messageBus.addEvent(BusEvent('$name.start'));
    await reloadCall();
    timer.stop();
    // 'restarted in 1.6s'
    final String message = '${name}ed in ${renderDuration(timer.elapsed)}';
    messageBus.addEvent(BusEvent('$name.end', data: message));
    // TODO(devoncarew): Add analytics.
    //ga.select(ga.devToolsMain, ga.hotRestart, timer.elapsed.inMilliseconds);
  } catch (_) {
    final String message = 'error performing $name';
    messageBus.addEvent(BusEvent('$name.end', data: message));
    rethrow;
  }
}

/// Button that when clicked invokes a VM Service , such as hot reload or hot
/// restart.
///
/// This button will attempt to register to the given service description.
class _RegisteredServiceExtensionButton extends _ServiceExtensionWidget {
  const _RegisteredServiceExtensionButton._({
    @required this.serviceDescription,
    @required this.action,
    @required String completedText,
    @required String Function(dynamic error) describeError,
  }) : super(completedText: completedText, describeError: describeError);

  /// The service to subscribe to.
  final RegisteredServiceDescription serviceDescription;

  /// The action to perform when clicked.
  final Future<void> Function() action;

  @override
  _RegisteredServiceExtensionButtonState createState() =>
      _RegisteredServiceExtensionButtonState();
}

class _RegisteredServiceExtensionButtonState
    extends State<_RegisteredServiceExtensionButton>
    with _ServiceExtensionMixin, AutoDisposeMixin {
  bool _hidden = true;

  @override
  void initState() {
    super.initState();

    // Only show the button if the device supports the given service.
    final serviceRegisteredListenable = serviceManager
        .registeredServiceListenable(widget.serviceDescription.service);
    addAutoDisposeListener(serviceRegisteredListenable, () {
      final registered = serviceRegisteredListenable.value;
      setState(() {
        _hidden = !registered;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox();

    return InkWell(
      onTap: () => invokeAndCatchErrors(widget.action),
      child: Container(
        constraints: const BoxConstraints.tightFor(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
        ),
        alignment: Alignment.center,
        // TODO(djshuckerow): Just make these icons the right size to fit this
        // box. The current size is a little tiny by comparison to our other
        // material icons.
        child: widget.serviceDescription.icon,
      ),
    );
  }
}

/// Control that toggles the value of [structuredErrors].
class StructuredErrorsToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _ServiceExtensionToggle(
      service: structuredErrors,
      describeError: (error) =>
          'Failed to update structuredError settings: $error',
    );
  }
}

/// [Switch] that stays synced with the value of a service extension.
///
/// Service extensions can be found in [service_extensions.dart].
class _ServiceExtensionToggle extends _ServiceExtensionWidget {
  const _ServiceExtensionToggle({
    Key key,
    this.service,
    @required String Function(dynamic) describeError,
  }) : super(
          key: key,
          // Don't show messages on success or when this toggle is in progress.
          completedText: null,
          describeError: describeError,
        );
  final ToggleableServiceExtensionDescription service;

  @override
  _ServiceExtensionMixin<_ServiceExtensionWidget> createState() =>
      _ServiceExtensionToggleState();
}

class _ServiceExtensionToggleState extends State<_ServiceExtensionToggle>
    with _ServiceExtensionMixin, AutoDisposeMixin {
  bool value = false;

  @override
  void initState() {
    super.initState();
    final state = serviceManager.serviceExtensionManager
        .getServiceExtensionState(widget.service.extension);

    value = state.value.enabled;

    addAutoDisposeListener(
      state,
      () {
        setState(() {
          value = state.value.enabled;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value
          ? widget.service.enabledTooltip
          : widget.service.disabledTooltip,
      waitDuration: tooltipWait,
      child: InkWell(
        onTap: _onClick,
        child: Row(
          children: <Widget>[
            Switch(
              value: value,
              onChanged: _onClick,
            ),
            Text(widget.service.description),
            // The switch is padded on its sides by 16dp.
            // This balances out the tappable area.
            const Padding(padding: EdgeInsets.only(left: defaultSpacing)),
          ],
        ),
      ),
    );
  }

  void _onClick([_]) {
    setState(() {
      value = !value;
    });

    invokeAndCatchErrors(() async {
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        widget.service.extension,
        value,
        value ? widget.service.enabledValue : widget.service.disabledValue,
      );
    });
  }
}

/// Widget that knows how to talk to a service extension and surface the relevant errors.
abstract class _ServiceExtensionWidget extends StatefulWidget {
  const _ServiceExtensionWidget(
      {Key key, @required this.completedText, @required this.describeError})
      : assert(describeError != null),
        super(key: key);

  /// The text to show when the action is completed.
  ///
  /// This will be shown in a [SnackBar], replacing the [inProgressText].
  final String completedText;

  /// Callback that describes any error that occurs.
  ///
  /// This will replace the [inProgressText] in a [SnackBar].
  final String Function(dynamic error) describeError;

  @override
  _ServiceExtensionMixin<_ServiceExtensionWidget> createState();
}

/// State mixin that manages calling an async service extension and reports
/// errors.
mixin _ServiceExtensionMixin<T extends _ServiceExtensionWidget> on State<T> {
  /// Whether an action is currently in progress.
  ///
  /// When [disabled], [invokeAndCatchErrors] will not accept new actions.
  @protected
  bool disabled = false;

  /// Invokes [action], showing [SnackBar]s for the action's progress,
  /// completion, and any errors it produces.
  @protected
  Future<void> invokeAndCatchErrors(Future<void> Function() action) async {
    if (disabled) {
      return;
    }

    setState(() {
      disabled = true;
    });

    try {
      await action();

      if (mounted && widget.completedText != null) {
        Notifications.of(context).push(widget.completedText);
      }
    } catch (e, st) {
      log('$e\n$st');

      if (mounted) {
        Notifications.of(context).push(widget.describeError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          disabled = false;
        });
      }
    }
  }
}

// TODO(jacobr): port these classes to Flutter.
/*
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

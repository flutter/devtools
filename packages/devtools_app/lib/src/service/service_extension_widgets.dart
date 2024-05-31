// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/constants.dart';
import '../shared/globals.dart';
import '../shared/primitives/message_bus.dart';
import '../shared/primitives/utils.dart';
import '../shared/ui/colors.dart';
import '../shared/ui/hover.dart';
import 'service_extensions.dart';
import 'service_registrations.dart';

final _log = Logger('service_extension_widgets');

/// Data class tracking the state of a single service extension.
class ExtensionState {
  ExtensionState(this.description);

  final ToggleableServiceExtensionDescription description;
  bool isSelected = false;
  bool isAvailable = false;
}

/// Group of buttons where each button toggles the state of a VMService
/// extension.
///
/// Use this class any time you need to write UI code that exposes button(s) to
/// control VMServiceExtension. This class handles error handling and lifecycle
/// states for keeping state on the client and device consistent so you don't
/// have to.
class ServiceExtensionButtonGroup extends StatefulWidget {
  const ServiceExtensionButtonGroup({
    super.key,
    this.minScreenWidthForTextBeforeScaling,
    required this.extensions,
  });

  final double? minScreenWidthForTextBeforeScaling;
  final List<ToggleableServiceExtensionDescription> extensions;

  @override
  State<ServiceExtensionButtonGroup> createState() =>
      _ServiceExtensionButtonGroupState();
}

class _ServiceExtensionButtonGroupState
    extends State<ServiceExtensionButtonGroup>
    with
        AutoDisposeMixin<ServiceExtensionButtonGroup>,
        MainIsolateChangeMixin<ServiceExtensionButtonGroup> {
  late List<ExtensionState> _extensionStates;

  @override
  void initState() {
    super.initState();
    // To use ToggleButtons we have to track states for all buttons in the
    // group here rather than tracking state with the individual button widgets
    // which would be more natural.
    _initExtensionState();
  }

  @override
  void _onMainIsolateChanged() => _initExtensionState();

  void _initExtensionState() {
    _extensionStates = [for (final e in widget.extensions) ExtensionState(e)];

    for (final extension in _extensionStates) {
      // Listen for changes to the state of each service extension using the
      // VMServiceManager.
      final extensionName = extension.description.extension;
      // Update the button state to match the latest state on the VM.
      final state = serviceConnection.serviceManager.serviceExtensionManager
          .getServiceExtensionState(extensionName);
      extension.isSelected = state.value.enabled;
      addAutoDisposeListener(state, () {
        setState(() {
          extension.isSelected = state.value.enabled;
        });
      });

      // Track whether the extension is actually exposed by the VM.
      final listenable = serviceConnection
          .serviceManager.serviceExtensionManager
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
      cancelListeners();
      _initExtensionState();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): respect _available better by displaying whether individual
    // widgets are available (not currently supported by ToggleButtons).
    final available = _extensionStates.any((e) => e.isAvailable);
    return SizedBox(
      height: defaultButtonHeight,
      child: DevToolsToggleButtonGroup(
        selectedStates: [for (final e in _extensionStates) e.isSelected],
        onPressed: available ? _onPressed : null,
        children: <Widget>[
          for (final extensionState in _extensionStates)
            ServiceExtensionButton(
              extensionState: extensionState,
              minScreenWidthForTextBeforeScaling:
                  widget.minScreenWidthForTextBeforeScaling,
            ),
        ],
      ),
    );
  }

  void _onPressed(int index) {
    final extensionState = _extensionStates[index];
    if (extensionState.isAvailable) {
      setState(() {
        final gaScreenName = extensionState.description.gaScreenName;
        final gaItem = extensionState.description.gaItem;
        if (gaScreenName != null && gaItem != null) {
          ga.select(gaScreenName, gaItem);
        }

        final wasSelected = extensionState.isSelected;

        unawaited(
          serviceConnection.serviceManager.serviceExtensionManager
              .setServiceExtensionState(
            extensionState.description.extension,
            enabled: !wasSelected,
            value: wasSelected
                ? extensionState.description.disabledValue
                : extensionState.description.enabledValue,
          ),
        );
      });
    } else {
      // TODO(jacobr): display a toast warning that the extension is
      // not available. That could happen as entire groups have to
      // be enabled or disabled at a time.
    }
  }
}

class ServiceExtensionButton extends StatelessWidget {
  const ServiceExtensionButton({
    super.key,
    required this.extensionState,
    required this.minScreenWidthForTextBeforeScaling,
  });

  final ExtensionState extensionState;

  final double? minScreenWidthForTextBeforeScaling;

  @override
  Widget build(BuildContext context) {
    final description = extensionState.description;

    return ServiceExtensionTooltip(
      description: description,
      child: Container(
        height: defaultButtonHeight,
        padding: EdgeInsets.symmetric(
          horizontal:
              isScreenWiderThan(context, minScreenWidthForTextBeforeScaling)
                  ? defaultSpacing
                  : 0.0,
        ),
        child: ImageIconLabel(
          ServiceExtensionIcon(extensionState: extensionState),
          description.title,
          unscaledMinIncludeTextWidth: minScreenWidthForTextBeforeScaling,
        ),
      ),
    );
  }
}

/// Button that performs a hot reload on the [serviceConnection].
class HotReloadButton extends StatelessWidget {
  const HotReloadButton({super.key, this.callOnVmServiceDirectly = false});

  /// Whether to initiate hot reload via [VmService.reloadSources] instead of by
  /// calling a registered service from Flutter.
  final bool callOnVmServiceDirectly;

  static const _hotReloadTooltip = 'Hot reload';

  @override
  Widget build(BuildContext context) {
    // TODO(devoncarew): Show as disabled when reload service calls are in progress.
    return callOnVmServiceDirectly
        // We cannot use a [_RegisteredServiceExtensionButton] here because
        // there is no hot reload service extension when we are calling hot
        // reload directly on the VM service (e.g. for Dart CLI apps).
        ? _HotReloadScaffoldAction()
        : DevToolsTooltip(
            message: _hotReloadTooltip,
            child: _RegisteredServiceExtensionButton._(
              serviceDescription: hotReload,
              action: _callHotReload,
              completedText: 'Hot reload completed.',
              describeError: (error) => 'Unable to hot reload the app: $error',
            ),
          );
  }
}

class _HotReloadScaffoldAction extends ScaffoldAction {
  _HotReloadScaffoldAction()
      : super(
          icon: hotReloadIcon,
          tooltip: HotReloadButton._hotReloadTooltip,
          onPressed: (context) {
            ga.select(gac.devToolsMain, gac.hotReload);
            _callHotReload();
          },
        );
}

Future<void> _callHotReload() {
  // The future is returned.
  // ignore: discarded_futures
  return serviceConnection.serviceManager.runDeviceBusyTask(
    // The future is returned.
    // ignore: discarded_futures
    _wrapReloadCall(
      'reload',
      serviceConnection.serviceManager.performHotReload,
    ),
  );
}

/// Button that performs a hot restart on the [serviceConnection].
class HotRestartButton extends StatelessWidget {
  const HotRestartButton({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(devoncarew): Show as disabled when reload service calls are in progress.

    return DevToolsTooltip(
      message: 'Hot restart',
      child: _RegisteredServiceExtensionButton._(
        serviceDescription: hotRestart,
        action: () {
          // The future is returned.
          // ignore: discarded_futures
          return serviceConnection.serviceManager.runDeviceBusyTask(
            // The future is returned.
            // ignore: discarded_futures
            _wrapReloadCall(
              'restart',
              serviceConnection.serviceManager.performHotRestart,
            ),
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
    final String message = '${name}ed in ${durationText(timer.elapsed)}';
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
class _RegisteredServiceExtensionButton extends ServiceExtensionWidget {
  const _RegisteredServiceExtensionButton._({
    required this.serviceDescription,
    required this.action,
    required String super.completedText,
    required super.describeError,
  });

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
    with ServiceExtensionMixin, AutoDisposeMixin {
  bool _hidden = true;

  @override
  void initState() {
    super.initState();

    // Only show the button if the device supports the given service.
    final serviceRegisteredListenable = serviceConnection.serviceManager
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
    if (_hidden) return const SizedBox.shrink();

    return InkWell(
      onTap: () => unawaited(
        invokeAndCatchErrors(() async {
          final gaScreenName = widget.serviceDescription.gaScreenName;
          final gaItem = widget.serviceDescription.gaItem;
          if (gaScreenName != null && gaItem != null) {
            ga.select(gaScreenName, gaItem);
          }
          await widget.action();
        }),
      ),
      child: Container(
        constraints: BoxConstraints.tightFor(
          width: actionWidgetSize,
          height: actionWidgetSize,
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
  const StructuredErrorsToggle({super.key});

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
class _ServiceExtensionToggle extends ServiceExtensionWidget {
  const _ServiceExtensionToggle({
    required this.service,
    required super.describeError,
  }) : super(
          completedText: null,
        );
  final ToggleableServiceExtensionDescription service;

  @override
  ServiceExtensionMixin<ServiceExtensionWidget> createState() =>
      _ServiceExtensionToggleState();
}

class _ServiceExtensionToggleState extends State<_ServiceExtensionToggle>
    with
        ServiceExtensionMixin,
        AutoDisposeMixin<_ServiceExtensionToggle>,
        MainIsolateChangeMixin<_ServiceExtensionToggle> {
  bool value = false;

  @override
  void initState() {
    super.initState();
    _initExtensionState();
  }

  @override
  void _onMainIsolateChanged() => _initExtensionState();

  void _initExtensionState() {
    final state = serviceConnection.serviceManager.serviceExtensionManager
        .getServiceExtensionState(widget.service.extension);
    value = state.value.enabled;

    addAutoDisposeListener(state, () {
      setState(() {
        value = state.value.enabled;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ServiceExtensionTooltip(
      description: widget.service,
      child: InkWell(
        onTap: _onClick,
        child: Row(
          children: <Widget>[
            DevToolsSwitch(
              padding: const EdgeInsets.only(right: denseSpacing),
              value: value,
              onChanged: _onClick,
            ),
            Text(widget.service.title),
          ],
        ),
      ),
    );
  }

  void _onClick([_]) {
    setState(() {
      value = !value;
    });

    unawaited(
      invokeAndCatchErrors(() async {
        await serviceConnection.serviceManager.serviceExtensionManager
            .setServiceExtensionState(
          widget.service.extension,
          enabled: value,
          value: value
              ? widget.service.enabledValue
              : widget.service.disabledValue,
        );
      }),
    );
  }
}

/// [Checkbox] that stays synced with the value of a service extension.
///
/// Service extensions can be found in [service_extensions.dart].
class ServiceExtensionCheckbox extends ServiceExtensionWidget {
  ServiceExtensionCheckbox({
    super.key,
    required this.serviceExtension,
    this.showDescription = true,
  }) : super(
          completedText: null,
          describeError: (error) => _errorMessage(
            serviceExtension.extension,
            error,
          ),
        );

  static String _errorMessage(String extensionName, Object? error) {
    return 'Failed to update $extensionName setting: $error';
  }

  final ToggleableServiceExtensionDescription serviceExtension;

  final bool showDescription;

  @override
  ServiceExtensionMixin<ServiceExtensionWidget> createState() =>
      _ServiceExtensionCheckboxState();
}

class _ServiceExtensionCheckboxState extends State<ServiceExtensionCheckbox>
    with
        ServiceExtensionMixin,
        AutoDisposeMixin<ServiceExtensionCheckbox>,
        MainIsolateChangeMixin<ServiceExtensionCheckbox> {
  /// Whether this checkbox value is set to true.
  ///
  /// This notifier listens to extension state changes from the service manager
  /// and will propagate those changes to the checkbox accordingly.
  final value = ValueNotifier<bool>(false);

  /// Whether the extension for this checkbox is available.
  final extensionAvailable = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _initExtensionState();
  }

  @override
  void _onMainIsolateChanged() => _initExtensionState();

  void _initExtensionState() {
    if (serviceConnection.serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(widget.serviceExtension.extension)) {
      final state = serviceConnection.serviceManager.serviceExtensionManager
          .getServiceExtensionState(widget.serviceExtension.extension);
      _setValueFromState(state.value);
    }

    unawaited(
      serviceConnection.serviceManager.serviceExtensionManager
          .waitForServiceExtensionAvailable(widget.serviceExtension.extension)
          .then((isServiceAvailable) {
        if (isServiceAvailable) {
          extensionAvailable.value = true;
          final state = serviceConnection.serviceManager.serviceExtensionManager
              .getServiceExtensionState(widget.serviceExtension.extension);
          _setValueFromState(state.value);
          addAutoDisposeListener(state, () {
            _setValueFromState(state.value);
          });
        }
      }),
    );
  }

  void _setValueFromState(ServiceExtensionState state) {
    final valueFromState = state.enabled;
    value.value =
        widget.serviceExtension.inverted ? !valueFromState : valueFromState;
  }

  @override
  Widget build(BuildContext context) {
    final docsUrl = widget.serviceExtension.documentationUrl;
    return ValueListenableBuilder<bool>(
      valueListenable: extensionAvailable,
      builder: (context, available, _) {
        return Row(
          children: [
            Expanded(
              child: CheckboxSetting(
                notifier: value,
                title: widget.serviceExtension.title,
                description: widget.showDescription
                    ? widget.serviceExtension.description
                    : null,
                tooltip: widget.serviceExtension.tooltip,
                onChanged: _onChanged,
                enabled: available,
                gaScreenName: widget.serviceExtension.gaScreenName,
                gaItem: widget.serviceExtension.gaItem,
              ),
            ),
            if (docsUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
                child: MoreInfoLink(
                  url: docsUrl,
                  gaScreenName: widget.serviceExtension.gaScreenName!,
                  gaSelectedItemDescription:
                      widget.serviceExtension.gaDocsItem!,
                  padding: const EdgeInsets.symmetric(vertical: denseSpacing),
                ),
              ),
          ],
        );
      },
    );
  }

  void _onChanged(bool? value) {
    unawaited(
      invokeAndCatchErrors(() async {
        var enabled = value == true;
        if (widget.serviceExtension.inverted) enabled = !enabled;
        await serviceConnection.serviceManager.serviceExtensionManager
            .setServiceExtensionState(
          widget.serviceExtension.extension,
          enabled: enabled,
          value: enabled
              ? widget.serviceExtension.enabledValue
              : widget.serviceExtension.disabledValue,
        );
      }),
    );
  }
}

/// A button that, when pressed, will display an overlay directly below that has
/// a list of service extension checkbox settings.
class ServiceExtensionCheckboxGroupButton extends StatefulWidget {
  ServiceExtensionCheckboxGroupButton({
    super.key,
    required this.title,
    required this.icon,
    required this.extensions,
    required this.overlayDescription,
    this.forceShowOverlayController,
    this.customExtensionUi = const <String, Widget>{},
    this.tooltip,
    double overlayWidthBeforeScaling = _defaultWidth,
    this.minScreenWidthForTextBeforeScaling,
  }) : overlayWidth = scaleByFontFactor(overlayWidthBeforeScaling);

  /// Title for the button.
  final String title;

  /// Icon for the button.
  final IconData icon;

  /// The minimum screen width for which this button should include text.
  final double? minScreenWidthForTextBeforeScaling;

  /// Extensions to be surfaced as checkbox settings in the overlay.
  final List<ToggleableServiceExtensionDescription> extensions;

  /// Maps service extensions to custom visualizations.
  ///
  /// If this map does not contain an entry for a service extension,
  /// [ServiceExtensionCheckbox] will be used to build the service extension
  /// setting in [_ServiceExtensionCheckboxGroupOverlay].
  final Map<String, Widget> customExtensionUi;

  /// Description for the checkbox settings overlay.
  ///
  /// This may contain instructions, a warning, or any message that is helpful
  /// to describe what the settings in this overlay are for. This widget should
  /// likely be a [Text] or [RichText] widget, but any widget can be used here.
  final Widget overlayDescription;

  final StreamController<void>? forceShowOverlayController;

  final String? tooltip;

  final double overlayWidth;

  static const _defaultWidth = 600.0;

  @override
  State<ServiceExtensionCheckboxGroupButton> createState() =>
      _ServiceExtensionCheckboxGroupButtonState();
}

class _ServiceExtensionCheckboxGroupButtonState
    extends State<ServiceExtensionCheckboxGroupButton>
    with
        AutoDisposeMixin<ServiceExtensionCheckboxGroupButton>,
        MainIsolateChangeMixin<ServiceExtensionCheckboxGroupButton> {
  static const _hoverYOffset = 10.0;

  /// Whether this button should have the enabled state, which makes the
  /// button appear with an enabled background color to indicate some
  /// non-default options are enabled.
  final _enabled = ValueNotifier(false);

  late List<bool> _extensionStates;

  OverlayEntry? _overlay;

  bool _overlayHovered = false;

  @override
  void initState() {
    super.initState();
    _initExtensionState();
  }

  @override
  void _onMainIsolateChanged() => _initExtensionState();

  void _initExtensionState() {
    _extensionStates = List.filled(widget.extensions.length, false);
    for (int i = 0; i < widget.extensions.length; i++) {
      final extension = widget.extensions[i];
      final state = serviceConnection.serviceManager.serviceExtensionManager
          .getServiceExtensionState(extension.extension);
      _extensionStates[i] = state.value.enabled;
      // Listen for extension state changes so that we can update the value of
      // [_activated].
      addAutoDisposeListener(state, () {
        _extensionStates[i] = state.value.enabled;
        _enabled.value = _isEnabled();
      });
    }
    _enabled.value = _isEnabled();

    if (widget.forceShowOverlayController != null) {
      cancelStreamSubscriptions();
      autoDisposeStreamSubscription(
        widget.forceShowOverlayController!.stream.listen((_) {
          if (mounted) _insertOverlay(context);
        }),
      );
    }
  }

  bool _isEnabled() {
    for (final state in _extensionStates) {
      if (state) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Widget label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      child: MaterialIconLabel(
        label: widget.title,
        iconData: widget.icon,
        minScreenWidthForTextBeforeScaling:
            widget.minScreenWidthForTextBeforeScaling,
      ),
    );
    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      label = DevToolsTooltip(message: widget.tooltip, child: label);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _enabled,
      builder: (context, enabled, _) {
        return DevToolsToggleButtonGroup(
          selectedStates: [enabled],
          onPressed: (_) => _insertOverlay(context),
          children: [label],
        );
      },
    );
  }

  /// Inserts an overlay with service extension toggles that will enhance the
  /// timeline trace.
  ///
  /// The overlay will appear directly below the button, and will be dismissed
  /// if there is a click outside of the list of toggles.
  void _insertOverlay(BuildContext context) {
    final width = math.min(
      widget.overlayWidth,
      MediaQuery.of(context).size.width - 2 * denseSpacing,
    );
    final offset = _calculateOverlayPosition(width, context);
    _overlay?.remove();
    Overlay.of(context).insert(
      _overlay = OverlayEntry(
        maintainState: true,
        builder: (context) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _maybeRemoveOverlay,
            child: Stack(
              children: [
                Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  child: MouseRegion(
                    onEnter: _mouseEnter,
                    onExit: _mouseExit,
                    child: _ServiceExtensionCheckboxGroupOverlay(
                      description: widget.overlayDescription,
                      extensions: widget.extensions,
                      width: width,
                      customExtensionUi: widget.customExtensionUi,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Offset _calculateOverlayPosition(double width, BuildContext context) {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;

    final maxX = overlayBox.size.width - width - denseSpacing;
    final maxY = overlayBox.size.height;

    final offset = box.localToGlobal(
      box.size.bottomCenter(Offset.zero).translate(-width / 2, _hoverYOffset),
      ancestor: overlayBox,
    );

    return Offset(
      offset.dx.clamp(denseSpacing, maxX),
      offset.dy.clamp(0.0, maxY),
    );
  }

  void _mouseEnter(PointerEnterEvent _) {
    _overlayHovered = true;
  }

  void _mouseExit(PointerExitEvent _) {
    _overlayHovered = false;
  }

  void _maybeRemoveOverlay() {
    if (!_overlayHovered) {
      _overlay?.remove();
      _overlay = null;
    }
  }
}

class _ServiceExtensionCheckboxGroupOverlay extends StatelessWidget {
  const _ServiceExtensionCheckboxGroupOverlay({
    required this.description,
    required this.extensions,
    required this.width,
    this.customExtensionUi = const <String, Widget>{},
  });

  /// Description for this checkbox settings overlay.
  ///
  /// This may contain instructions, a warning, or any message that is helpful
  /// to describe what the settings in this overlay are for. This widget should
  /// likely be a [Text] or [RichText] widget, but any widget can be used here.
  final Widget description;

  final List<ToggleableServiceExtensionDescription> extensions;

  final double width;

  /// Maps service extensions to custom visualizations.
  ///
  /// If this map does not contain an entry for a service extension,
  /// [ServiceExtensionCheckbox] will be used to build the service extension
  /// setting.
  final Map<String, Widget> customExtensionUi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      child: PointerInterceptor(
        child: Container(
          width: width,
          padding: const EdgeInsets.all(defaultSpacing),
          decoration: BoxDecoration(
            color: theme.colorScheme.defaultBackgroundColor,
            border: Border.all(
              color: theme.focusColor,
              width: hoverCardBorderSize,
            ),
            borderRadius: defaultBorderRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              description,
              const SizedBox(height: denseSpacing),
              for (final serviceExtension in extensions)
                _extensionSetting(serviceExtension),
            ],
          ),
        ),
      ),
    );
  }

  Widget _extensionSetting(ToggleableServiceExtensionDescription extension) {
    assert(extensions.contains(extension));
    final customUi = customExtensionUi[extension.extension];
    return customUi ?? ServiceExtensionCheckbox(serviceExtension: extension);
  }
}

/// Widget that knows how to talk to a service extension and surface the relevant errors.
abstract class ServiceExtensionWidget extends StatefulWidget {
  const ServiceExtensionWidget({
    super.key,
    required this.completedText,
    required this.describeError,
  });

  /// The text to show when the action is completed.
  ///
  /// This will be shown in a [SnackBar], replacing the [inProgressText].
  final String? completedText;

  /// Callback that describes any error that occurs.
  ///
  /// This will replace the [inProgressText] in a [SnackBar].
  final String Function(Object? error) describeError;

  @override
  ServiceExtensionMixin<ServiceExtensionWidget> createState();
}

/// State mixin that manages calling an async service extension and reports
/// errors.
mixin ServiceExtensionMixin<T extends ServiceExtensionWidget> on State<T> {
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
        notificationService.push(widget.completedText!);
      }
    } catch (e, st) {
      _log.info(e, e, st);

      if (mounted) {
        notificationService.push(widget.describeError(e));
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

class ServiceExtensionTooltip extends StatelessWidget {
  const ServiceExtensionTooltip({
    super.key,
    required this.description,
    required this.child,
  });

  final ToggleableServiceExtensionDescription description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (description.documentationUrl != null) {
      return ServiceExtensionRichTooltip(
        description: description,
        child: child,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final focusColor = theme.focusColor;
    return DevToolsTooltip(
      message: description.tooltip,
      preferBelow: true,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: focusColor,
          width: hoverCardBorderSize,
        ),
        borderRadius: defaultBorderRadius,
      ),
      textStyle: theme.regularTextStyle.copyWith(color: colorScheme.onSurface),
      child: child,
    );
  }
}

/// Rich tooltip with a description and "more info" link
class ServiceExtensionRichTooltip extends StatelessWidget {
  const ServiceExtensionRichTooltip({
    super.key,
    required this.description,
    required this.child,
  });

  final ToggleableServiceExtensionDescription description;
  final Widget child;

  static const double _tooltipWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    return HoverCardTooltip.sync(
      enabled: () => true,
      generateHoverCardData: (_) => _buildCardData(),
      child: child,
    );
  }

  HoverCardData _buildCardData() {
    return HoverCardData(
      position: HoverCardPosition.element,
      width: _tooltipWidth,
      contents: Material(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description.tooltip,
            ),
            if (description.documentationUrl != null &&
                description.gaScreenName != null)
              Align(
                alignment: Alignment.bottomRight,
                child: MoreInfoLink(
                  url: description.documentationUrl!,
                  gaScreenName: description.gaScreenName!,
                  gaSelectedItemDescription: description.gaItemTooltipLink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ServiceExtensionIcon extends StatelessWidget {
  const ServiceExtensionIcon({required this.extensionState, super.key});

  final ExtensionState extensionState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = extensionState.isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final description = extensionState.description;
    if (description.iconData != null) {
      return Icon(
        description.iconData,
        color: color,
      );
    }
    return Image(
      image: AssetImage(extensionState.description.iconAsset!),
      height: defaultIconSize,
      width: defaultIconSize,
      color: color,
    );
  }
}

mixin MainIsolateChangeMixin<T extends StatefulWidget>
    on State<T>, AutoDisposeMixin<T> {
  static const _mainIsolateListenerId = 'mainIsolateListener';

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      () {
        setState(() {
          cancelListeners(excludeIds: [_mainIsolateListenerId]);
          _onMainIsolateChanged();
        });
      },
      _mainIsolateListenerId,
    );
  }

  void _onMainIsolateChanged();
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
    selector.disabled = !serviceManager.manager.serviceExtensionManager
        .isServiceExtensionAvailable(extensionName);
    serviceManager.manager.serviceExtensionManager.hasServiceExtension(
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

    serviceManager.manager.serviceExtensionManager.setServiceExtensionState(
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
    serviceManager.manager.serviceExtensionManager
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
    serviceManager.manager.serviceExtensionManager
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

// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../../../service/service_extension_widgets.dart';
import '../../../../../service/service_extensions.dart' as extensions;
import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/ui/common_widgets.dart';
import '../performance_controls.dart';
import 'enhance_tracing_controller.dart';

class EnhanceTracingButton extends StatelessWidget {
  const EnhanceTracingButton(this.enhanceTracingController, {super.key});

  static const title = 'Enhance Tracing';

  static const icon = Icons.auto_awesome;

  final EnhanceTracingController enhanceTracingController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.subtleTextStyle;
    return ServiceExtensionCheckboxGroupButton(
      title: title,
      icon: icon,
      tooltip: 'Add more detail to the Timeline trace',
      minScreenWidthForTextBeforeScaling:
          PerformanceControls.minScreenWidthForTextBeforeScaling,
      extensions: enhanceTracingExtensions,
      forceShowOverlayController:
          enhanceTracingController.showMenuStreamController,
      customExtensionUi: {
        extensions.profileWidgetBuilds.extension:
            const TraceWidgetBuildsSetting(),
        extensions.profileUserWidgetBuilds.extension: const SizedBox(),
      },
      overlayDescription: RichText(
        text: TextSpan(
          text:
              'These options can be used to add more detail to the '
              'timeline, but be aware that ',
          style: textStyle,
          children: [
            TextSpan(
              text: 'frame times may be negatively affected',
              style: textStyle.copyWith(color: theme.colorScheme.error),
            ),
            TextSpan(text: '.\n\n', style: textStyle),
            TextSpan(
              text:
                  'When toggling on/off a tracing option, you will need '
                  'to reproduce activity in your app to see the enhanced '
                  'tracing in the timeline.',
              style: textStyle,
            ),
          ],
        ),
      ),
    );
  }
}

enum TraceWidgetBuildsScope { all, userCreated }

extension TraceWidgetBuildsScopeExtension on TraceWidgetBuildsScope {
  String get radioDisplay {
    switch (this) {
      case TraceWidgetBuildsScope.all:
        return 'within all code';
      case TraceWidgetBuildsScope.userCreated:
        return 'within your code';
    }
  }

  /// Returns the opposite [TraceWidgetBuildsScope] from [this].
  TraceWidgetBuildsScope get opposite {
    switch (this) {
      case TraceWidgetBuildsScope.all:
        return TraceWidgetBuildsScope.userCreated;
      case TraceWidgetBuildsScope.userCreated:
        return TraceWidgetBuildsScope.all;
    }
  }

  /// Returns the service extension for this [TraceWidgetBuildsScope].
  extensions.ToggleableServiceExtensionDescription<bool> get extensionForScope {
    switch (this) {
      case TraceWidgetBuildsScope.all:
        return extensions.profileWidgetBuilds;
      case TraceWidgetBuildsScope.userCreated:
        return extensions.profileUserWidgetBuilds;
    }
  }
}

class TraceWidgetBuildsSetting extends StatefulWidget {
  const TraceWidgetBuildsSetting({super.key});

  @override
  State<TraceWidgetBuildsSetting> createState() =>
      _TraceWidgetBuildsSettingState();
}

class _TraceWidgetBuildsSettingState extends State<TraceWidgetBuildsSetting>
    with AutoDisposeMixin {
  static const _scopeSelectorPadding = 32.0;

  /// Service extensions for tracing widget builds.
  final _traceWidgetBuildsExtensions = {
    TraceWidgetBuildsScope.all: extensions.profileWidgetBuilds,
    TraceWidgetBuildsScope.userCreated: extensions.profileUserWidgetBuilds,
  };

  /// The selected trace widget builds scope, which may be any value in
  /// [TraceWidgetBuildsScope] or null if widget builds are not being traced.
  final _selectedScope = ValueNotifier<TraceWidgetBuildsScope?>(null);

  /// Whether either of the extensions in [_traceWidgetBuildsExtensions.values]
  /// are enabled.
  final _tracingEnabled = ValueNotifier<bool>(false);

  /// Whether either of the extensions in [_traceWidgetBuildsExtensions.values]
  /// are available.
  final _tracingAvailable = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    // Listen for service extensions to become available and add a listener to
    // respond to their state changes.
    for (final type in TraceWidgetBuildsScope.values) {
      final extension = _traceWidgetBuildsExtensions[type]!;

      unawaited(
        serviceConnection.serviceManager.serviceExtensionManager
            .waitForServiceExtensionAvailable(extension.extension)
            .then((isServiceAvailable) {
              if (isServiceAvailable) {
                _tracingAvailable.value = true;

                final state = serviceConnection
                    .serviceManager
                    .serviceExtensionManager
                    .getServiceExtensionState(extension.extension);

                _updateForServiceExtensionState(state.value, type);
                addAutoDisposeListener(state, () {
                  _updateForServiceExtensionState(state.value, type);
                });
              }
            }),
      );
    }
  }

  @override
  void dispose() {
    _tracingEnabled.dispose();
    _selectedScope.dispose();
    _tracingAvailable.dispose();
    super.dispose();
  }

  Future<void> _updateForServiceExtensionState(
    ServiceExtensionState newState,
    TraceWidgetBuildsScope type,
  ) async {
    final otherState =
        serviceConnection.serviceManager.serviceExtensionManager
            .getServiceExtensionState(type.opposite.extensionForScope.extension)
            .value
            .enabled;
    final traceAllWidgets =
        type == TraceWidgetBuildsScope.all ? newState.enabled : otherState;
    final traceUserWidgets =
        type == TraceWidgetBuildsScope.userCreated
            ? newState.enabled
            : otherState;
    await _updateTracing(
      traceAllWidgets: traceAllWidgets,
      traceUserWidgets: traceUserWidgets,
    );
  }

  Future<void> _updateTracing({
    required bool traceAllWidgets,
    required bool traceUserWidgets,
  }) async {
    if (traceUserWidgets && traceAllWidgets) {
      // If both the debug setting for tracing all widgets and tracing only
      // user-created widgets are true, default to tracing only user-created
      // widgets. Disable the service extension for tracing all widgets.
      await serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
            extensions.profileWidgetBuilds.extension,
            enabled: false,
            value: extensions.profileWidgetBuilds.disabledValue,
          );
      traceAllWidgets = false;
    }

    assert(!(traceAllWidgets && traceUserWidgets));
    _tracingEnabled.value = traceUserWidgets || traceAllWidgets;
    // Double nested conditinoal expressions are hard to read.
    // ignore: prefer-conditional-expression
    if (_tracingEnabled.value) {
      _selectedScope.value =
          traceUserWidgets
              ? TraceWidgetBuildsScope.userCreated
              : TraceWidgetBuildsScope.all;
    } else {
      _selectedScope.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _tracingAvailable,
          builder: (context, tracingAvailable, _) {
            return TraceWidgetBuildsCheckbox(
              tracingNotifier: _tracingEnabled,
              enabled: tracingAvailable,
            );
          },
        ),
        MultiValueListenableBuilder(
          listenables: [_tracingEnabled, _selectedScope],
          builder: (context, values, _) {
            final tracingEnabled = values.first as bool;
            final selectedScope = values.second as TraceWidgetBuildsScope?;
            return Padding(
              padding: const EdgeInsets.only(left: _scopeSelectorPadding),
              child: TraceWidgetBuildsScopeSelector(
                scope: selectedScope,
                enabled: tracingEnabled,
              ),
            );
          },
        ),
      ],
    );
  }
}

class TraceWidgetBuildsCheckbox extends StatelessWidget {
  const TraceWidgetBuildsCheckbox({
    super.key,
    required this.tracingNotifier,
    required this.enabled,
  });

  final ValueNotifier<bool> tracingNotifier;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final extension = extensions.profileWidgetBuilds;
    final docsUrl = extension.documentationUrl;
    return Row(
      children: [
        Expanded(
          child: CheckboxSetting(
            notifier: tracingNotifier,
            title: extension.title,
            description: extension.description,
            tooltip: extension.tooltip,
            onChanged: _checkboxChanged,
            enabled: enabled,
            gaScreen: extension.gaScreenName,
            gaItem: extension.gaItem,
          ),
        ),
        if (docsUrl != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
            child: MoreInfoLink(
              url: docsUrl,
              gaScreenName: extension.gaScreenName!,
              gaSelectedItemDescription: extension.gaDocsItem!,
              padding: const EdgeInsets.symmetric(vertical: denseSpacing),
            ),
          ),
      ],
    );
  }

  void _checkboxChanged(bool? value) async {
    final enabled = value == true;
    final tracingExtensions = TraceWidgetBuildsScope.values.map(
      (scope) => scope.extensionForScope,
    );
    if (enabled) {
      // Default to tracing only user-created widgets.
      final extension = extensions.profileUserWidgetBuilds;
      await serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
            extension.extension,
            enabled: true,
            value: extension.enabledValue,
          );
    } else {
      await [
        for (final extension in tracingExtensions)
          serviceConnection.serviceManager.serviceExtensionManager
              .setServiceExtensionState(
                extension.extension,
                enabled: false,
                value: extension.disabledValue,
              ),
      ].wait;
    }
  }
}

class TraceWidgetBuildsScopeSelector extends StatelessWidget {
  const TraceWidgetBuildsScopeSelector({
    super.key,
    required this.scope,
    required this.enabled,
  });

  final TraceWidgetBuildsScope? scope;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = enabled ? theme.regularTextStyle : theme.subtleTextStyle;
    return Row(
      children: [
        ..._scopeSetting(
          TraceWidgetBuildsScope.userCreated,
          textStyle: textStyle,
        ),
        const SizedBox(width: defaultSpacing),
        ..._scopeSetting(TraceWidgetBuildsScope.all, textStyle: textStyle),
      ],
    );
  }

  List<Widget> _scopeSetting(
    TraceWidgetBuildsScope type, {
    TextStyle? textStyle,
  }) {
    return [
      Radio<TraceWidgetBuildsScope>(
        value: type,
        groupValue: scope,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: enabled ? _changeScope : null,
      ),
      Text(type.radioDisplay, style: textStyle),
    ];
  }

  Future<void> _changeScope(TraceWidgetBuildsScope? type) async {
    assert(enabled);
    final extension = type!.extensionForScope;
    final opposite = type.opposite.extensionForScope;
    await [
      serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
            opposite.extension,
            enabled: false,
            value: opposite.disabledValue,
          ),
      serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
            extension.extension,
            enabled: true,
            value: extension.enabledValue,
          ),
    ].wait;
  }
}

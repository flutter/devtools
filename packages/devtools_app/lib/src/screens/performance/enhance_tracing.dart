// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../service/service_extension_manager.dart';
import '../../service/service_extension_widgets.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/theme.dart';
import 'performance_screen.dart';

class EnhanceTracingButton extends StatelessWidget {
  const EnhanceTracingButton({Key? key}) : super(key: key);

  static const title = 'Enhance Tracing';

  static const icon = Icons.auto_awesome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.subtleTextStyle;
    return ServiceExtensionCheckboxGroupButton(
      title: title,
      icon: icon,
      tooltip: 'Add more detail to the Timeline trace',
      minScreenWidthForTextBeforeScaling:
          SecondaryPerformanceControls.minScreenWidthForTextBeforeScaling,
      extensions: [
        extensions.profileWidgetBuilds,
        extensions.profileUserWidgetBuilds,
        extensions.profileRenderObjectLayouts,
        extensions.profileRenderObjectPaints,
      ],
      customExtensionUi: {
        extensions.profileWidgetBuilds.extension:
            const TrackWidgetBuildsSetting(),
        extensions.profileUserWidgetBuilds.extension: const SizedBox(),
      },
      overlayDescription: RichText(
        text: TextSpan(
          text: 'These options can be used to add more detail to the '
              'timeline, but be aware that ',
          style: textStyle,
          children: [
            TextSpan(
              text: 'frame times may be negatively affected',
              style:
                  textStyle.copyWith(color: theme.colorScheme.errorTextColor),
            ),
            TextSpan(
              text: '.\n\n',
              style: textStyle,
            ),
            TextSpan(
              text: 'When toggling on/off a tracing option, you will need '
                  'to reproduce activity in your app to see the enhanced '
                  'tracing in the timeline.',
              style: textStyle,
            )
          ],
        ),
      ),
    );
  }
}

enum TrackWidgetBuildsScope {
  all,
  userCreated,
}

extension TrackWidgetBuildsScopeExtension on TrackWidgetBuildsScope {
  String get radioDisplay {
    switch (this) {
      case TrackWidgetBuildsScope.all:
        return 'within all code';
      case TrackWidgetBuildsScope.userCreated:
        return 'within your code';
    }
  }

  /// Returns the opposite [TrackWidgetBuildsScope] from [this].
  TrackWidgetBuildsScope get opposite {
    switch (this) {
      case TrackWidgetBuildsScope.all:
        return TrackWidgetBuildsScope.userCreated;
      case TrackWidgetBuildsScope.userCreated:
        return TrackWidgetBuildsScope.all;
    }
  }

  /// Returns the service extension for this [TrackWidgetBuildsScope].
  extensions.ToggleableServiceExtensionDescription<bool> get extensionForScope {
    switch (this) {
      case TrackWidgetBuildsScope.all:
        return extensions.profileWidgetBuilds;
      case TrackWidgetBuildsScope.userCreated:
        return extensions.profileUserWidgetBuilds;
    }
  }
}

class TrackWidgetBuildsSetting extends StatefulWidget {
  const TrackWidgetBuildsSetting({Key? key}) : super(key: key);

  @override
  State<TrackWidgetBuildsSetting> createState() =>
      _TrackWidgetBuildsSettingState();
}

class _TrackWidgetBuildsSettingState extends State<TrackWidgetBuildsSetting>
    with AutoDisposeMixin {
  static const _scopeSelectorPadding = 32.0;

  /// Service extensions for tracking widget builds.
  final _trackWidgetBuildsExtensions = {
    TrackWidgetBuildsScope.all: extensions.profileWidgetBuilds,
    TrackWidgetBuildsScope.userCreated: extensions.profileUserWidgetBuilds,
  };

  /// The selected track widget builds scope, which may be any value in
  /// [TrackWidgetBuildsScope] or null if widget builds are not being tracked.
  final _selectedScope = ValueNotifier<TrackWidgetBuildsScope?>(null);

  /// Whether either of the extensions in [_trackWidgetBuildsExtensions.values]
  /// are enabled.
  final _tracked = ValueNotifier<bool>(false);

  /// Whether either of the extensions in [_trackWidgetBuildsExtensions.values]
  /// are available.
  final _trackingAvailable = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    // Listen for service extensions to become available and add a listener to
    // respond to their state changes.
    for (final type in TrackWidgetBuildsScope.values) {
      final extension = _trackWidgetBuildsExtensions[type]!;
      serviceManager.serviceExtensionManager
          .waitForServiceExtensionAvailable(extension.extension)
          .then((isServiceAvailable) {
        if (isServiceAvailable) {
          _trackingAvailable.value = true;

          final state = serviceManager.serviceExtensionManager
              .getServiceExtensionState(extension.extension);

          _updateForServiceExtensionState(state.value, type);
          addAutoDisposeListener(state, () {
            _updateForServiceExtensionState(state.value, type);
          });
        }
      });
    }
  }

  Future<void> _updateForServiceExtensionState(
    ServiceExtensionState newState,
    TrackWidgetBuildsScope type,
  ) async {
    final otherState = serviceManager.serviceExtensionManager
        .getServiceExtensionState(type.opposite.extensionForScope.extension)
        .value
        .enabled;
    final trackAllWidgets =
        type == TrackWidgetBuildsScope.all ? newState.enabled : otherState;
    final trackUserWidgets = type == TrackWidgetBuildsScope.userCreated
        ? newState.enabled
        : otherState;
    await _updateTracking(
      trackAllWidgets: trackAllWidgets,
      trackUserWidgets: trackUserWidgets,
    );
  }

  Future<void> _updateTracking({
    required bool trackAllWidgets,
    required bool trackUserWidgets,
  }) async {
    if (trackUserWidgets && trackAllWidgets) {
      // If both the debug setting for tracking all widgets and tracking only
      // user-created widgets are true, default to tracking only user-created
      // widgets. Disable the service extension for tracking all widgets.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensions.profileWidgetBuilds.extension,
        enabled: false,
        value: extensions.profileWidgetBuilds.disabledValue,
      );
      trackAllWidgets = false;
    }

    assert(!(trackAllWidgets && trackUserWidgets));
    _tracked.value = trackUserWidgets || trackAllWidgets;
    if (_tracked.value) {
      _selectedScope.value = trackUserWidgets
          ? TrackWidgetBuildsScope.userCreated
          : TrackWidgetBuildsScope.all;
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
          valueListenable: _trackingAvailable,
          builder: (context, trackingAvailable, _) {
            return TrackWidgetBuildsCheckbox(
              trackingNotifier: _tracked,
              enabled: trackingAvailable,
            );
          },
        ),
        DualValueListenableBuilder<bool, TrackWidgetBuildsScope?>(
          firstListenable: _tracked,
          secondListenable: _selectedScope,
          builder: (context, tracked, selectedScope, _) {
            return Padding(
              padding: const EdgeInsets.only(left: _scopeSelectorPadding),
              child: TrackWidgetBuildsScopeSelector(
                scope: selectedScope,
                enabled: tracked,
              ),
            );
          },
        ),
      ],
    );
  }
}

class TrackWidgetBuildsCheckbox extends StatelessWidget {
  const TrackWidgetBuildsCheckbox({
    Key? key,
    required this.trackingNotifier,
    required this.enabled,
  }) : super(key: key);

  final ValueNotifier<bool> trackingNotifier;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final extension = extensions.profileWidgetBuilds;
    final docsUrl = extension.documentationUrl;
    return Row(
      children: [
        Expanded(
          child: CheckboxSetting(
            notifier: trackingNotifier,
            title: extension.title,
            description: extension.description,
            tooltip: extension.tooltip,
            onChanged: _checkboxChanged,
            enabled: enabled,
            gaScreenName: extension.gaScreenName,
            gaItem: extension.gaItem,
          ),
        ),
        if (docsUrl != null)
          MoreInfoLink(
            url: docsUrl,
            gaScreenName: extension.gaScreenName!,
            gaSelectedItemDescription: extension.gaDocsItem!,
            padding: const EdgeInsets.symmetric(vertical: denseSpacing),
          ),
      ],
    );
  }

  void _checkboxChanged(bool? value) async {
    final enabled = value == true;
    final trackingExtensions =
        TrackWidgetBuildsScope.values.map((scope) => scope.extensionForScope);
    if (enabled) {
      // Default to tracking only user-created widgets.
      final extension = extensions.profileUserWidgetBuilds;
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        extension.extension,
        enabled: true,
        value: extension.enabledValue,
      );
    } else {
      await Future.wait([
        for (final extension in trackingExtensions)
          serviceManager.serviceExtensionManager.setServiceExtensionState(
            extension.extension,
            enabled: false,
            value: extension.disabledValue,
          )
      ]);
    }
  }
}

class TrackWidgetBuildsScopeSelector extends StatelessWidget {
  const TrackWidgetBuildsScopeSelector({
    Key? key,
    required this.scope,
    required this.enabled,
  }) : super(key: key);

  final TrackWidgetBuildsScope? scope;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = enabled ? theme.regularTextStyle : theme.subtleTextStyle;
    return Row(
      children: [
        ..._scopeSetting(
          TrackWidgetBuildsScope.userCreated,
          textStyle: textStyle,
        ),
        const SizedBox(width: defaultSpacing),
        ..._scopeSetting(
          TrackWidgetBuildsScope.all,
          textStyle: textStyle,
        ),
      ],
    );
  }

  List<Widget> _scopeSetting(
    TrackWidgetBuildsScope type, {
    TextStyle? textStyle,
  }) {
    return [
      Radio<TrackWidgetBuildsScope>(
        value: type,
        groupValue: scope,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: enabled ? _changeScope : null,
      ),
      Text(
        type.radioDisplay,
        style: textStyle,
      ),
    ];
  }

  Future<void> _changeScope(TrackWidgetBuildsScope? type) async {
    assert(enabled);
    final extension = type!.extensionForScope;
    final opposite = type.opposite.extensionForScope;
    await Future.wait(
      [
        serviceManager.serviceExtensionManager.setServiceExtensionState(
          opposite.extension,
          enabled: false,
          value: opposite.disabledValue,
        ),
        serviceManager.serviceExtensionManager.setServiceExtensionState(
          extension.extension,
          enabled: true,
          value: extension.enabledValue,
        ),
      ],
    );
  }
}

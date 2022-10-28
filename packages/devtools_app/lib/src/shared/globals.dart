// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../config_specific/ide_theme/ide_theme.dart';
import '../config_specific/import_export/import_export.dart';
import '../extension_points/extensions_base.dart';
import '../primitives/message_bus.dart';
import '../primitives/storage.dart';
import '../screens/debugger/breakpoint_manager.dart';
import '../scripts/script_manager.dart';
import '../service/service_manager.dart';
import '../shared/notifications.dart';
import 'framework_controller.dart';
import 'preferences.dart';
import 'survey.dart';

/// Whether this DevTools build is external.
bool get isExternalBuild => _isExternalBuild;
bool _isExternalBuild = true;

/// Flag the build as external.
void setExternalBuild() => _isExternalBuild = true;

final Map<Type, dynamic> globals = <Type, dynamic>{};

ServiceConnectionManager get serviceManager =>
    globals[ServiceConnectionManager];

ScriptManager get scriptManager => globals[ScriptManager];

MessageBus get messageBus => globals[MessageBus];

FrameworkController get frameworkController => globals[FrameworkController];

Storage get storage => globals[Storage];

SurveyService get surveyService => globals[SurveyService];

PreferencesController get preferences => globals[PreferencesController];

DevToolsExtensionPoints get devToolsExtensionPoints =>
    globals[DevToolsExtensionPoints];

OfflineModeController get offlineController => globals[OfflineModeController];

IdeTheme get ideTheme => globals[IdeTheme];

NotificationService get notificationService => globals[NotificationService];

BreakpointManager get breakpointManager => globals[BreakpointManager];

void setGlobal(Type clazz, dynamic instance) {
  globals[clazz] = instance;
}

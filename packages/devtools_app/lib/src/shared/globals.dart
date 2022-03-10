// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import '../config_specific/ide_theme/ide_theme.dart';
import '../config_specific/import_export/import_export.dart';
import '../extension_points/extensions_base.dart';
import '../primitives/message_bus.dart';
import '../primitives/storage.dart';
import '../service/service_manager.dart';
import 'framework_controller.dart';
import 'preferences.dart';
import 'survey.dart';

final Map<Type, dynamic> globals = <Type, dynamic>{};

ServiceConnectionManager get serviceManager =>
    globals[ServiceConnectionManager];

MessageBus get messageBus => globals[MessageBus];

FrameworkController get frameworkController => globals[FrameworkController];

Storage get storage => globals[Storage];

SurveyService get surveyService => globals[SurveyService];

PreferencesController get preferences => globals[PreferencesController];

DevToolsExtensionPoints get devToolsExtensionPoints =>
    globals[DevToolsExtensionPoints];

OfflineModeController get offlineController => globals[OfflineModeController];

IdeTheme? get ideTheme => globals[IdeTheme];

void setGlobal(Type clazz, dynamic instance) {
  globals[clazz] = instance;
}

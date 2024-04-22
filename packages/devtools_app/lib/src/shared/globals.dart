// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../extensions/extension_service.dart';
import '../screens/debugger/breakpoint_manager.dart';
import '../service/service_manager.dart';
import '../shared/banner_messages.dart';
import '../shared/notifications.dart';
import 'console/eval/eval_service.dart';
import 'environment_parameters/environment_parameters_base.dart';
import 'framework_controller.dart';
import 'offline_data.dart';
import 'preferences/preferences.dart';
import 'primitives/message_bus.dart';
import 'primitives/storage.dart';
import 'scripts/script_manager.dart';
import 'survey.dart';

/// Whether this DevTools build is external.
bool get isExternalBuild => _isExternalBuild;
bool _isExternalBuild = true;
void setInternalBuild() => _isExternalBuild = false;

ServiceConnectionManager get serviceConnection =>
    globals[ServiceConnectionManager] as ServiceConnectionManager;

ScriptManager get scriptManager => globals[ScriptManager] as ScriptManager;

MessageBus get messageBus => globals[MessageBus] as MessageBus;

FrameworkController get frameworkController =>
    globals[FrameworkController] as FrameworkController;

Storage get storage => globals[Storage] as Storage;

SurveyService get surveyService => globals[SurveyService] as SurveyService;

DTDManager get dtdManager => globals[DTDManager] as DTDManager;

PreferencesController get preferences =>
    globals[PreferencesController] as PreferencesController;

DevToolsEnvironmentParameters get devToolsExtensionPoints =>
    globals[DevToolsEnvironmentParameters] as DevToolsEnvironmentParameters;

OfflineDataController get offlineDataController =>
    globals[OfflineDataController] as OfflineDataController;

NotificationService get notificationService =>
    globals[NotificationService] as NotificationService;

BannerMessagesController get bannerMessages =>
    globals[BannerMessagesController] as BannerMessagesController;

BreakpointManager get breakpointManager =>
    globals[BreakpointManager] as BreakpointManager;

EvalService get evalService => globals[EvalService] as EvalService;

ExtensionService get extensionService =>
    globals[ExtensionService] as ExtensionService;

/// Whether DevTools is being run in integration test mode.
bool get integrationTestMode => _integrationTestMode;
bool _integrationTestMode = false;
void setIntegrationTestMode() {
  _integrationTestMode = true;
}

/// Whether DevTools is being run in a test environment.
bool get testMode => _testMode;
bool _testMode = false;
void setTestMode() {
  _testMode = true;
}

/// Whether DevTools is being run as a stager app.
bool get stagerMode => _stagerMode;
bool _stagerMode = false;
void setStagerMode() {
  if (!kReleaseMode) {
    _stagerMode = true;
  }
}

/// Whether DevTools is being run in any type of testing mode.
bool get anyTestMode => _integrationTestMode || _testMode || _stagerMode;

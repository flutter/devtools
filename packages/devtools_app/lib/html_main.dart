// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:html_shim/html.dart';
import 'package:pedantic/pedantic.dart';
import 'package:platform_detect/platform_detect.dart';

import 'src/framework/framework_core.dart';
import 'src/main.dart';
import 'src/ui/analytics.dart' as ga;
import 'src/ui/analytics_platform.dart' as platform;

void main() {
  // Run in a zone in order to catch all Dart exceptions.
  runZoned(
    () async {
      // Initialize the core framework.
      FrameworkCore.init(window.location.toString());

      // Hookup for possbile analytic collection.
      ga.exposeGaDevToolsEnabledToJs();

      if (ga.isGtagsReset()) {
        ga.resetDevToolsFile();
      }

      // Load the web app framework.
      final HtmlPerfToolFramework framework = HtmlPerfToolFramework();

      // TODO(terry): Eventually remove the below line localStorage clear().
      /// Nothing is now stored in Chrome's local store - remove old stuff.
      window.localStorage.clear();

      // Show the opt-in dialog for collection analytics?
      try {
        if (ga.isGtagsEnabled()) {
          if (await ga.isFirstRun) {
            framework.showAnalyticsDialog();
          } else if (await ga.isEnabled) {
            // Analytic collection is enabled - setup for analytics.
            platform.initializeGA();
            platform.jsHookupListenerForGA();
          }
        }
      } catch (e) {
        // If there are errors setting up analytics, write them to the console
        // but do not prevent DevTools from loading.
        window.console.error(e);
      }

      if (!browser.isChrome) {
        final browserName =
            // Edge shows up as IE, so we replace it's name to avoid confusion.
            browser.isInternetExplorer || browser == Browser.UnknownBrowser
                ? 'an unsupported browser'
                : browser.name;
        framework.disableAppWithError(
          'ERROR: You are running DevTools on $browserName, '
              'but DevTools only runs on Chrome.',
          'Reopen this url in a Chrome browser to use DevTools.',
        );
        return;
      }

      // Show the Q1 DevTools survey. Stop showing the survey after March 9,
      // 2020 (4 weeks after the survey start date February 10, 2020).
      final surveyStartDate = DateTime(2020, 2, 10);
      final surveyEndDate = DateTime(2020, 3, 9);
      final now = DateTime.now();
      if (now.isAfter(surveyStartDate) && now.isBefore(surveyEndDate)) {
        // Do not show the survey if the user has either taken or dismissed it.
        if (!await ga.isSurveyActionTaken) {
          // Stop showing the survey toast after 5 times without action.
          if (await ga.surveyShownCount < 5) {
            framework.surveyToast(await _generateSurveyUrl());
            await ga.incrementSurveyShownCount;
          }
        }
      }

      unawaited(FrameworkCore.initVmService(
        window.location.toString(),
        errorReporter: (String title, dynamic error) {
          framework.showError(title, error);
        },
      ).then((bool connected) {
        if (!connected) {
          framework.showConnectionDialog();
          framework.showSnapshotMessage();
          // Clear the main element so it stops displaying "Loading..."
          // TODO(jacobr): display a message explaining how to launch a Flutter
          // application from the command line and connect to it with DevTools.
          framework.mainElement.clear();
        }
      }));

      framework.loadScreenFromLocation();
    },
    zoneSpecification: const ZoneSpecification(
      handleUncaughtError: _handleUncaughtError,
    ),
  );
}

Future<String> _generateSurveyUrl() async {
  const clientIdKey = 'ClientId';
  const ideKey = 'IDE';
  const fromKey = 'From';
  const internalKey = 'Internal';

  final uri = Uri.parse(window.location.toString());
  final ideValue = uri.queryParameters[ga.ideLaunchedQuery] ?? 'CLI';
  final fromValue = uri.fragment ?? '';
  final clientId = await ga.flutterGAClientID();

  // TODO(djshuckerow): override this value for internal users.
  const internalValue = 'false';

  final surveyUri = Uri(
    scheme: 'https',
    host: 'google.qualtrics.com',
    path: 'jfe/form/SV_9XDmbo8lhv0VaUl',
    queryParameters: {
      clientIdKey: clientId,
      ideKey: ideValue,
      fromKey: fromValue,
      internalKey: internalValue,
    },
  );
  return surveyUri.toString();
}

void _handleUncaughtError(
  Zone self,
  ZoneDelegate parent,
  Zone zone,
  Object error,
  StackTrace stackTrace,
) {
  // TODO(devoncarew): `stackTrace` always seems to be null.

  // Report exceptions with DevTools to GA; user's Flutter app exceptions are
  // not collected.
  ga.error('$error\n${stackTrace ?? ''}'.trim(), true);

  final Console console = window.console;

  // Also write them to the console to aid debugging.
  final errorLines = error.toString().split('\n');
  console.groupCollapsed(
      'DevTools exception: [${error.runtimeType}] ${errorLines.first}');
  console.log(errorLines.skip(1).join('\n'));

  if (stackTrace != null) {
    if (errorLines.length > 1) {
      console.log('\n');
    }
    console.log(stackTrace.toString().trim());
  }

  console.groupEnd();
}

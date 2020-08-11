// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library analytics_platform;

import 'dart:async';
import 'dart:html' as html;

import 'package:js/js.dart';

import '../config_specific/logger/logger.dart';
import '../globals.dart';
import 'analytics.dart' as ga;

@JS('getDevToolsPropertyID')
external String devToolsProperty();

@JS('hookupListenerForGA')
external void jsHookupListenerForGA();

Future<bool> get isAnalyticsAllowed async => await ga.isEnabled;

void setAllowAnalytics() {
  ga.setEnabled();
}

void setDontAllowAnalytics() {
  ga.setEnabled(false);
}

/// Computes the DevTools application. Fills in the devtoolsPlatformType and
/// devtoolsChrome.
void computeDevToolsCustomGTagsData() {
  // Platform
  final String platform = html.window.navigator.platform;
  platform.replaceAll(' ', '_');
  ga.devtoolsPlatformType = platform;

  final String appVersion = html.window.navigator.appVersion;
  final List<String> splits = appVersion.split(' ');
  final len = splits.length;
  for (int index = 0; index < len; index++) {
    final String value = splits[index];
    // Chrome or Chrome iOS
    if (value.startsWith(ga.devToolsChromeName) ||
        value.startsWith(ga.devToolsChromeIos)) {
      ga.devtoolsChrome = value;
    } else if (value.startsWith('Android')) {
      // appVersion for Android is 'Android n.n.n'
      ga.devtoolsPlatformType =
          '${ga.devToolsPlatformTypeAndroid}${splits[index + 1]}';
    } else if (value == ga.devToolsChromeOS) {
      // Chrome OS will return a platform e.g., CrOS_Linux_x86_64
      ga.devtoolsPlatformType = '${ga.devToolsChromeOS}_$platform';
    }
  }
}

// Look at the query parameters '&ide=' and record in GA.
void computeDevToolsQueryParams() {
  ga.ideLaunched = ga.ideLaunchedCLI; // Default is Command Line launch.

  final Uri uri = Uri.parse(html.window.location.toString());
  final ideValue = uri.queryParameters[ga.ideLaunchedQuery];
  if (ideValue != null) {
    ga.ideLaunched = ideValue;
  }
}

void computeFlutterClientId() async {
  final flutterClientId = await ga.flutterGAClientID();
  ga.flutterClientId = flutterClientId;
}

bool _computing = false;

int _stillWaiting = 0;
void waitForDimensionsComputed(String screenName) {
  Timer(const Duration(milliseconds: 100), () async {
    if (ga.isDimensionsComputed) {
      ga.screen(screenName);
    } else {
      if (_stillWaiting++ < 50) {
        waitForDimensionsComputed(screenName);
      } else {
        log('Cancel waiting for dimensions.', LogLevel.warning);
      }
    }
  });
}

// Loading screen from a hash code, can't collect GA (if enabled) until we have
// all the dimension data.
void setupAndGaScreen(String screenName) async {
  if (ga.isGtagsEnabled()) {
    if (!ga.isDimensionsComputed) {
      _stillWaiting++;
      waitForDimensionsComputed(screenName);
    } else {
      ga.screen(screenName);
    }
  }
}

void setupDimensions() async {
  if (serviceManager.connectedApp != null &&
      ga.isGtagsEnabled() &&
      !ga.isDimensionsComputed &&
      !_computing) {
    _computing = true;
    // While spinning up DevTools first time wait until dimensions data is
    // available before first GA event sent.
    await ga.computeUserApplicationCustomGTagData();
    computeDevToolsCustomGTagsData();
    computeDevToolsQueryParams();
    computeFlutterClientId();
    ga.dimensionsComputed();
  }
}

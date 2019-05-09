// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library analytics_platform;

import 'dart:async';
import 'dart:html' as html;

import 'package:js/js.dart';

import '../globals.dart';
import '../ui/analytics.dart' as ga;

@JS('getDevToolsPropertyID')
external String devToolsProperty();

@JS('gaStorageCollect')
external String storageCollectValue();

@JS('gaStorageDontCollect')
external String storageDontCollectValue();

bool isAnalyticsAllowed() =>
    html.window.localStorage[devToolsProperty()] == storageCollectValue();

void setAllowAnalytics() {
  html.window.localStorage[devToolsProperty()] = storageCollectValue();
}

void setDontAllowAnalytics() {
  html.window.localStorage[devToolsProperty()] = storageDontCollectValue();
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
        print('Cancel waiting for dimensions.');
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
    ga.dimensionsComputed();
  }
}

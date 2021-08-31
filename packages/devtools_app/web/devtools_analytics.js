// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Used for GA collecting (communicating to https://www.googletagmanager.com/gtag/js script).
window.dataLayer = window.dataLayer || [];
function gtag() {
  dataLayer.push(arguments);
}

// InitializeGA with our dimensions. Both the name and order (dimension #) should match the those in gtags.dart
function initializeGA() {
  console.log('initializing ga from inside devtools_analytics.js');
  gtag('js', new Date());
  gtag('config', GA_DEVTOOLS_PROPERTY, {
    'custom_map': {
      // Custom dimensions:
      'dimension1': 'user_app',
      'dimension2': 'user_build',
      'dimension3': 'user_platform',
      'dimension4': 'devtools_platform',
      'dimension5': 'devtools_chrome',
      'dimension6': 'devtools_version',
      'dimension7': 'ide_launched',
      'dimension8': 'flutter_client_id',
       // Custom metrics:
      'metric1': 'ui_duration_micros',
      'metric2': 'raster_duration_micros',
      'metric3': 'shader_compilation_duration_micros',
      'metric4': 'cpu_sample_count',
      'metric5': 'cpu_stack_depth',
    }
  });
}

function hookupListenerForGA() {
  // Record when DevTools browser tab is selected (visible), not selected (hidden) or browser minimized.
  document.addEventListener('visibilitychange', function (e) {
    if (window.gaDevToolsEnabled()) {
      gtag('event', document.visibilityState, {
        event_category: 'application',
      });
    }
  });
}

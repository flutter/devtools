// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// URI parameter to control DevTools analytics collection:
//
//   &gtags=enabled                 // Analytics will run but ga-confirm and opt-in must work (see ga-confirm below).
//   &gtags=disabled                // Default is disabled implies no GA will run (even opt-in dialog won't display).
//
//   &ga-confirm=?                  // Displays the GA collection confirmation dialog, to change answer.
//   &ga-confirm=reset              // Resets/deletes user's collection answer in local storage.
//   &ga-confirm=true               // Analytics COLLECT opt-in answer from an outside application e.g., VSCode.
//   &ga-confirm=false              // Analytics DO NOT COLLECT opt-in answer from an outside application e.g., VSCode.

window.dataLayer = window.dataLayer || [];

function gtag() {
    if (gtagsEnabled()) {
        dataLayer.push(arguments);
    }
}

function _getUrlVars() {
    let allVars = {};
    window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/gi, function(_, key, value) {
        allVars[key] = value;
    });
    return allVars;
}

let _urlVars = _getUrlVars();

let _gtagsEnabled = _urlVars['gtags'] == 'enabled' ? true : false;
function gtagsEnabled() {
    return _gtagsEnabled
}

let gaConfirmation = _urlVars['ga-confirm'];

let _initializedGA = false;
function isGaInitialized() {
    return gtagsEnabled() && _initializedGA;
}

// InitializeGA with our dimensions. Both the name and order (dimension #) should match the those in gtags.dart
function _initializeGA() {
    if (gtagsEnabled() && !_initializedGA && gaCollectionAllowed()) {
        gtag('js', new Date());
        gtag('config', _GA_DEVTOOLS_PROPERTY, {
            'custom_map': {
                // Custom dimensions:
                dimension1: 'user_app',
                dimension2: 'user_build',
                dimension3: 'user_platform',
                dimension4: 'devtools_platform',
                dimension5: 'devtools_chrome',
                dimension6: 'devtools_version',

                // Custom metrics:
                metric1: 'gpu_duration',
                metric2: 'ui_duration',
            }
        });

        _initializedGA = true;
    }
}

// Values in local storage:
const _GA_COLLECT = 'collect';
const _GA_DONT_COLLECT = 'do-not-collect';

function gaCollectionAllowed() {
    return localStorage.getItem(_GA_DEVTOOLS_PROPERTY) == _GA_COLLECT;
}

let gaDialog = document.getElementById('devtools_analytics');

if (!gtagsEnabled()) {
    gaDialog.close();
    console.log("gtags not enabled.");
}

gaDialog.style.zIndex = '1000';

// '?' to ga-confirm URI parameter to display GA acceptance dialog e.g.,  &ga-confirm=?
if (gtagsEnabled()) {
    if (gaConfirmation != null) {
        console.log("GA &ga-confirm = " + gaConfirmation);
    }
    console.log("GA Dart DevTools Property " + _GA_DEVTOOLS_PROPERTY + " opt-in = " + localStorage.getItem(_GA_DEVTOOLS_PROPERTY));
}

if (gaConfirmation == '?' || localStorage.getItem(_GA_DEVTOOLS_PROPERTY) == null) {
    let gaAcceptButton = document.getElementById('devtools-ga-accept');
    gaAcceptButton.addEventListener('click', function (_) {
        // Collect statistics.
        localStorage.setItem(_GA_DEVTOOLS_PROPERTY, _GA_COLLECT);
        gaDialog.close();
        _initializeGA();
    });

    let gaDoNotAcceptButton = document.getElementById('devtools-ga-do-not-accept');
    gaDoNotAcceptButton.addEventListener('click', function (_) {
        // Do NOT collect statistics.
        localStorage.setItem(_GA_DEVTOOLS_PROPERTY, _GA_DONT_COLLECT);
        gaDialog.close();
    });

    // Ensure focus doesn't leave GA confirmation dialog.
    gaDialog.addEventListener('focusout', function (e) {
        // Collect statistics.
        let cancelEvent = false;
        let relatedTarget = e.relatedTarget;
        if (relatedTarget != null) {
            let id = relatedTarget.getAttribute('id');
            cancelEvent = id == null || !id.startsWith('devtools-ga-');
        } else {
            cancelEvent = true;
        }
        if (cancelEvent) {
            e.srcElement.focus();
            e.stopPropagation();
            e.preventDefault();
            return false;
        }
    });
} else if (gaConfirmation == 'reset') {
    // Delete the local storage value.
    localStorage.removeItem(_GA_DEVTOOLS_PROPERTY);
    gaDialog.style.display = 'none';
    console.log("Reset localStorage = " + localStorage.getItem(_GA_DEVTOOLS_PROPERTY));
} else {
    gaDialog.style.display = 'none';

    // If gaConfirmation is passed in e.g., VSCode and DevTools GA Collection not defined then use VSCode's collection
    // authorization.  Otherwise, DevTools GA collection, if explicitly defined use DevTools regardless if VSCode's
    // is different.
    if (gaConfirmation == 'true' && localStorage.getItem(_GA_DEVTOOLS_PROPERTY) == null) {
        localStorage.setItem(_GA_DEVTOOLS_PROPERTY, gaConfirmation == 'true' ? _GA_COLLECT : _GA_DONT_COLLECT);
    } else if (gaConfirmation == 'false') {
        // If GA confirmation is to not collect statistics then immediately force no collection regardless of what
        // DevTools GA Confirmation was always default to DO NOT COLLECT if anyone up the line has do not collect.
        localStorage.setItem(_GA_DEVTOOLS_PROPERTY, _GA_DONT_COLLECT);
    }
}

_initializeGA();

if (gtagsEnabled()) {
// Record when DevTools browser tab is selected (visible), not selected (hidden) or browser minimized.
    document.addEventListener("visibilitychange", function (e) {
        if (gaCollectionAllowed()) {
            gtag('event', document.visibilityState, {
                event_category: 'application',
            });
        }
    });
}
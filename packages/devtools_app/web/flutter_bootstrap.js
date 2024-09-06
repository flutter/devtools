{{flutter_js}}
{{flutter_build_config}}

// Unregister the old custom DevTools service worker (if it exists). It was
// removed in: https://github.com/flutter/devtools/pull/5331
function unregisterDevToolsServiceWorker() {
  if ('serviceWorker' in navigator) {
    const DEVTOOLS_SW = 'service_worker.js';
    const FLUTTER_SW = 'flutter_service_worker.js';
    navigator.serviceWorker.getRegistrations().then(function(registrations) {
        for (let registration of registrations) {
            const activeWorker = registration.active;
            if (activeWorker != null) {
                const url = activeWorker.scriptURL;
                if (url.includes(DEVTOOLS_SW) && !url.includes(FLUTTER_SW)) {
                    registration.unregister();
                }
            }
        }
    });
  }
}

// Calls the DevTools server API to read the user's wasm preference.
async function getDevToolsWasmPreference() {
  const request = 'api/getPreferenceValue?key=experiment.wasm';
  try {
    const response = await fetch(request);
    if (!response.ok) {
      console.warn(`[${response.status} response] ${request}`);
      return false;
    }

    // The response text should be an encoded boolean value ("true" or "false").
    return JSON.parse(await response.text());
  } catch (error) {
    console.error('Error fetching experiment.wasm preference value:', error);
    return false;
  }
}

// Bootstrap app for 3P environments:
async function bootstrapAppFor3P() {
  // This query parameter must match the String value specified by
  // `DevToolsQueryParameters.wasmKey`. See
  // devtools/packages/devtools_app/lib/src/shared/query_parameters.dart
  const wasmQueryParameterKey = 'wasm';
  
  const searchParams = new URLSearchParams(window.location.search);
  const wasmEnabledFromQueryParameter = searchParams.get(wasmQueryParameterKey) === 'true';
  const wasmEnabledFromDevToolsPreference = await getDevToolsWasmPreference();

  // Add the 'wasm=true' query parameter if WASM should be enabled based on
  // the DevTools preferences, but the query parameter is not set to 'true'.
  if (wasmEnabledFromDevToolsPreference === true && wasmEnabledFromQueryParameter === false) {
    const url = new URL(window.location.href); // Get the current URL object
    url.searchParams.set(wasmQueryParameterKey, 'true');
    // Update the browser's history without reloading
    window.history.pushState({}, '', url); 
  }

  const shouldUseSkwasm = wasmEnabledFromQueryParameter === true || wasmEnabledFromDevToolsPreference === true;
  const renderer = shouldUseSkwasm  ? 'skwasm' : 'canvaskit';
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    config: {
      canvasKitBaseUrl: 'canvaskit/',
      renderer: renderer,
    }
  });
}

// Bootstrap app for 1P environments:
function bootstrapAppFor1P() {
  _flutter.loader.load();
}

unregisterDevToolsServiceWorker();
bootstrapAppFor3P();

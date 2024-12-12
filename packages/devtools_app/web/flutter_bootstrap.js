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

// This query parameter must match the String value specified by
// `DevToolsQueryParameters.wasmKey`. See
// devtools/packages/devtools_app/lib/src/shared/query_parameters.dart
const wasmQueryParameterKey = 'wasm';

// Calls the DevTools server API to read the user's wasm preference.
async function getDevToolsWasmPreference() {
  // Note: when the DevTools server is running on a different port than the
  // DevTools web app, this request path will be incorrect and the request
  // will fail. This is okay because DevTools cannot be built with WASM when
  // running from `flutter run` anyway.
  const request = 'api/getPreferenceValue?key=experiment.wasm';
  try {
    const response = await fetch(request);
    if (!response.ok) {
      console.warn(`[${response.status} response] ${request}`);
      return false;
    }

    // The response text should be an encoded boolean value ("true" or "false").
    const wasmEnabled = JSON.parse(await response.text());
    return wasmEnabled === true || wasmEnabled === 'true';
  } catch (error) {
    console.error('Error fetching experiment.wasm preference value:', error);
    return false;
  }
}

// Returns whether DevTools should be loaded with the skwasm renderer based on the
// value of the 'wasm' query parameter or the wasm setting from the DevTools
// preference file.
async function shouldUseSkwasm() {
  const searchParams = new URLSearchParams(window.location.search);
  const wasmEnabledFromQueryParameter = searchParams.get(wasmQueryParameterKey) === 'true';
  const wasmEnabledFromDevToolsPreference = await getDevToolsWasmPreference();
  return wasmEnabledFromQueryParameter === true || wasmEnabledFromDevToolsPreference === true;
}

// Sets or removes the 'wasm' query parameter based on whether DevTools should
// be loaded with the skwasm renderer.
function updateWasmQueryParameter(useSkwasm) {
  const url = new URL(window.location.href);
  if (useSkwasm) {
    url.searchParams.set(wasmQueryParameterKey, 'true');
  } else {
    url.searchParams.delete(wasmQueryParameterKey);
  }
  // Update the browser's history without reloading. This is a no-op if the wasm
  // query parameter does not actually need to be updated.
  window.history.pushState({}, '', url);
}

// Bootstrap app for 3P environments:
async function bootstrapAppFor3P() {
  const useSkwasm = await shouldUseSkwasm();

  // Ensure the 'wasm' query parameter in the URL is accurate for the renderer
  // DevTools will be loaded with.
  updateWasmQueryParameter(useSkwasm);

  const rendererForLog = useSkwasm ? 'skwasm' : 'canvaskit';
  console.log('Attempting to load DevTools with ' + rendererForLog + ' renderer.');

  const rendererConfig = useSkwasm ? {} : { renderer: 'canvaskit' };
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    config: {
      canvasKitBaseUrl: 'canvaskit/',
      ...rendererConfig,
    }
  });
}

// Bootstrap app for 1P environments:
function bootstrapAppFor1P() {
  _flutter.loader.load();
}

unregisterDevToolsServiceWorker();
bootstrapAppFor3P();

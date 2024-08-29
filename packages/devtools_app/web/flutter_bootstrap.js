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

// Bootstrap app for 3P environments:
function bootstrapAppFor3P() {
  const searchParams = new URLSearchParams(window.location.search);
  // This query parameter must match the String value specified by
  // `DevToolsQueryParameters.wasmKey`. See
  // devtools/packages/devtools_app/lib/src/shared/query_parameters.dart
  const useWasm = searchParams.get('wasm');

  // TODO(https://github.com/flutter/devtools/issues/7856): can we also
  // look up the wasm preference from the DevTools preferences file? Can
  // we make a direct call to the DevTools server from here?
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    config: {
      canvasKitBaseUrl: 'canvaskit/',
      renderer: useWasm ? 'skwasm' : 'canvaskit'
    }
  });
}

// Bootstrap app for 1P environments:
function bootstrapAppFor1P() {
  _flutter.loader.load();
}

unregisterDevToolsServiceWorker();
bootstrapAppFor3P();

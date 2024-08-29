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

function getDevToolsWasmPreference() {
  // TODO(https://github.com/flutter/devtools/issues/7856): can we also
  // look up the wasm preference from the DevTools preferences file? Can
  // we make a direct call to the DevTools server from here?
  fetch('api/sse/')
  const eventSource = new EventSource('/api/sse');
  eventSource.onopen = () => {
    console.log('SSE connection opened.');
  };

  eventSource.onmessage = (event) => {
    const data = JSON.parse(event.data); 
    console.log('Received data:', data);
  };

  eventSource.onerror = (error) => {
    console.error('SSE error:', error);
    eventSource.close(); 
  };

  console.log('eventSource.url: ' + eventSource.url);

  return true;
}

// Bootstrap app for 3P environments:
function bootstrapAppFor3P() {
  const searchParams = new URLSearchParams(window.location.search);
  // This query parameter must match the String value specified by
  // `DevToolsQueryParameters.wasmKey`. See
  // devtools/packages/devtools_app/lib/src/shared/query_parameters.dart
  const wasmEnabledFromQueryParameter = searchParams.get('wasm');
  console.log('wasmEnabledFromQueryParameter: ' + wasmEnabledFromQueryParameter);
  console.log('wasmEnabledFromQueryParameter === \'true\' : ' + wasmEnabledFromQueryParameter === 'true');

  const wasmEnabledFromDevToolsPreference = getDevToolsWasmPreference();
  console.log('wasmEnabledFromDevToolsPreference: ' + wasmEnabledFromDevToolsPreference);

  console.log('boolean value: ' + wasmEnabledFromQueryParameter || wasmEnabledFromDevToolsPreference);

  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    config: {
      canvasKitBaseUrl: 'canvaskit/',
      renderer: wasmEnabledFromQueryParameter === 'true' || wasmEnabledFromDevToolsPreference 
        ? 'skwasm' 
        : 'canvaskit'
    }
  });
}

// Bootstrap app for 1P environments:
function bootstrapAppFor1P() {
  _flutter.loader.load();
}

unregisterDevToolsServiceWorker();
bootstrapAppFor3P();

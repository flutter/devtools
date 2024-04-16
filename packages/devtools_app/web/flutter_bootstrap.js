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
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    config: {
      canvasKitBaseUrl: 'canvaskit/'
    }
  });
}

// Bootstrap app for 1P environments:
function bootstrapAppFor1P() {
  _flutter.loader.load({
    config: {
      canvasKitBaseUrl: 'canvaskit/'
    }
  });
}

unregisterDevToolsServiceWorker();
bootstrapAppFor3P();

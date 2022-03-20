// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This service worker is not run in local development mode. As part of the 
// release logic, it is moved to the build directory and renamed to 
// service_worker.js. The renamed service worker is the one that is loaded
// in index.html.

'use strict';

const CACHE_PREFIX = `dart-devtools-app-cache-`;

const RESOURCES_TO_CACHE = [
    '/main.dart.js',
    '/assets/',
];

self.addEventListener('install', (event) => {
    // Skip waiting to immediately stop any previously active service workers:
    self.skipWaiting();
    const resetCache = caches.keys()
        .then((cacheKeys) => {
            // Delete any older caches during installation of the new service worker:
            return Promise.all(cacheKeys.map((key) => caches.delete(key)));
        })
        .then(() => caches.open(getCacheName(self.location)));
    event.waitUntil(resetCache);
});

// The fetch handler redirects requests for RESOURCES_TO_CACHE to the service
// worker cache.
self.addEventListener('fetch', (event) => {
    if (event.request.method !== 'GET' ||
        isExternalRequest(event.request.url, self.location.origin) ||
        !shouldCache(event.request.url)) {
        // Signal that we don't want to cache the request and the browser should take over.
        return;
    }

    event.respondWith(caches.open(getCacheName(self.location)).then((cache) => {
        return cache.match(event.request).then((response) => {
            // Either respond with the cached resource, or perform a fetch and
            // lazily populate the cache.
            return response || fetch(event.request).then((response) => {
                cache.put(event.request, response.clone());
                return response;
            });
        });
    }));
});

function getCacheName(location) {
    const version = location.search.replace('?v=', '');
    return CACHE_PREFIX + version;
}

function isExternalRequest(requestUrl, originUrl) {
    return !requestUrl.includes(originUrl);
}

function shouldCache(requestUrl) {
    return RESOURCES_TO_CACHE.some((resourcePath) => requestUrl.includes(resourcePath));
}

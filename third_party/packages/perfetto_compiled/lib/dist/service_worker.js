var service_worker = (function () {
'use strict';

function getAugmentedNamespace(n) {
  if (n.__esModule) return n;
  var f = n.default;
	if (typeof f == "function") {
		var a = function a () {
			if (this instanceof a) {
				var args = [null];
				args.push.apply(args, arguments);
				var Ctor = Function.bind.apply(f, args);
				return new Ctor();
			}
			return f.apply(this, arguments);
		};
		a.prototype = f.prototype;
  } else a = {};
  Object.defineProperty(a, '__esModule', {value: true});
	Object.keys(n).forEach(function (k) {
		var d = Object.getOwnPropertyDescriptor(n, k);
		Object.defineProperty(a, k, d.get ? d : {
			enumerable: true,
			get: function () {
				return n[k];
			}
		});
	});
	return a;
}

var service_worker = {};

/******************************************************************************
Copyright (c) Microsoft Corporation.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
***************************************************************************** */
/* global Reflect, Promise */

var extendStatics = function(d, b) {
    extendStatics = Object.setPrototypeOf ||
        ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
        function (d, b) { for (var p in b) if (Object.prototype.hasOwnProperty.call(b, p)) d[p] = b[p]; };
    return extendStatics(d, b);
};

function __extends(d, b) {
    if (typeof b !== "function" && b !== null)
        throw new TypeError("Class extends value " + String(b) + " is not a constructor or null");
    extendStatics(d, b);
    function __() { this.constructor = d; }
    d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
}

var __assign = function() {
    __assign = Object.assign || function __assign(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p)) t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};

function __rest(s, e) {
    var t = {};
    for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p) && e.indexOf(p) < 0)
        t[p] = s[p];
    if (s != null && typeof Object.getOwnPropertySymbols === "function")
        for (var i = 0, p = Object.getOwnPropertySymbols(s); i < p.length; i++) {
            if (e.indexOf(p[i]) < 0 && Object.prototype.propertyIsEnumerable.call(s, p[i]))
                t[p[i]] = s[p[i]];
        }
    return t;
}

function __decorate(decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
}

function __param(paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
}

function __esDecorate(ctor, descriptorIn, decorators, contextIn, initializers, extraInitializers) {
    function accept(f) { if (f !== void 0 && typeof f !== "function") throw new TypeError("Function expected"); return f; }
    var kind = contextIn.kind, key = kind === "getter" ? "get" : kind === "setter" ? "set" : "value";
    var target = !descriptorIn && ctor ? contextIn["static"] ? ctor : ctor.prototype : null;
    var descriptor = descriptorIn || (target ? Object.getOwnPropertyDescriptor(target, contextIn.name) : {});
    var _, done = false;
    for (var i = decorators.length - 1; i >= 0; i--) {
        var context = {};
        for (var p in contextIn) context[p] = p === "access" ? {} : contextIn[p];
        for (var p in contextIn.access) context.access[p] = contextIn.access[p];
        context.addInitializer = function (f) { if (done) throw new TypeError("Cannot add initializers after decoration has completed"); extraInitializers.push(accept(f || null)); };
        var result = (0, decorators[i])(kind === "accessor" ? { get: descriptor.get, set: descriptor.set } : descriptor[key], context);
        if (kind === "accessor") {
            if (result === void 0) continue;
            if (result === null || typeof result !== "object") throw new TypeError("Object expected");
            if (_ = accept(result.get)) descriptor.get = _;
            if (_ = accept(result.set)) descriptor.set = _;
            if (_ = accept(result.init)) initializers.push(_);
        }
        else if (_ = accept(result)) {
            if (kind === "field") initializers.push(_);
            else descriptor[key] = _;
        }
    }
    if (target) Object.defineProperty(target, contextIn.name, descriptor);
    done = true;
}
function __runInitializers(thisArg, initializers, value) {
    var useValue = arguments.length > 2;
    for (var i = 0; i < initializers.length; i++) {
        value = useValue ? initializers[i].call(thisArg, value) : initializers[i].call(thisArg);
    }
    return useValue ? value : void 0;
}
function __propKey(x) {
    return typeof x === "symbol" ? x : "".concat(x);
}
function __setFunctionName(f, name, prefix) {
    if (typeof name === "symbol") name = name.description ? "[".concat(name.description, "]") : "";
    return Object.defineProperty(f, "name", { configurable: true, value: prefix ? "".concat(prefix, " ", name) : name });
}
function __metadata(metadataKey, metadataValue) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(metadataKey, metadataValue);
}

function __awaiter(thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
}

function __generator(thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
}

var __createBinding = Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
        desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
});

function __exportStar(m, o) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(o, p)) __createBinding(o, m, p);
}

function __values(o) {
    var s = typeof Symbol === "function" && Symbol.iterator, m = s && o[s], i = 0;
    if (m) return m.call(o);
    if (o && typeof o.length === "number") return {
        next: function () {
            if (o && i >= o.length) o = void 0;
            return { value: o && o[i++], done: !o };
        }
    };
    throw new TypeError(s ? "Object is not iterable." : "Symbol.iterator is not defined.");
}

function __read(o, n) {
    var m = typeof Symbol === "function" && o[Symbol.iterator];
    if (!m) return o;
    var i = m.call(o), r, ar = [], e;
    try {
        while ((n === void 0 || n-- > 0) && !(r = i.next()).done) ar.push(r.value);
    }
    catch (error) { e = { error: error }; }
    finally {
        try {
            if (r && !r.done && (m = i["return"])) m.call(i);
        }
        finally { if (e) throw e.error; }
    }
    return ar;
}

/** @deprecated */
function __spread() {
    for (var ar = [], i = 0; i < arguments.length; i++)
        ar = ar.concat(__read(arguments[i]));
    return ar;
}

/** @deprecated */
function __spreadArrays() {
    for (var s = 0, i = 0, il = arguments.length; i < il; i++) s += arguments[i].length;
    for (var r = Array(s), k = 0, i = 0; i < il; i++)
        for (var a = arguments[i], j = 0, jl = a.length; j < jl; j++, k++)
            r[k] = a[j];
    return r;
}

function __spreadArray(to, from, pack) {
    if (pack || arguments.length === 2) for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
            if (!ar) ar = Array.prototype.slice.call(from, 0, i);
            ar[i] = from[i];
        }
    }
    return to.concat(ar || Array.prototype.slice.call(from));
}

function __await(v) {
    return this instanceof __await ? (this.v = v, this) : new __await(v);
}

function __asyncGenerator(thisArg, _arguments, generator) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var g = generator.apply(thisArg, _arguments || []), i, q = [];
    return i = {}, verb("next"), verb("throw"), verb("return"), i[Symbol.asyncIterator] = function () { return this; }, i;
    function verb(n) { if (g[n]) i[n] = function (v) { return new Promise(function (a, b) { q.push([n, v, a, b]) > 1 || resume(n, v); }); }; }
    function resume(n, v) { try { step(g[n](v)); } catch (e) { settle(q[0][3], e); } }
    function step(r) { r.value instanceof __await ? Promise.resolve(r.value.v).then(fulfill, reject) : settle(q[0][2], r); }
    function fulfill(value) { resume("next", value); }
    function reject(value) { resume("throw", value); }
    function settle(f, v) { if (f(v), q.shift(), q.length) resume(q[0][0], q[0][1]); }
}

function __asyncDelegator(o) {
    var i, p;
    return i = {}, verb("next"), verb("throw", function (e) { throw e; }), verb("return"), i[Symbol.iterator] = function () { return this; }, i;
    function verb(n, f) { i[n] = o[n] ? function (v) { return (p = !p) ? { value: __await(o[n](v)), done: false } : f ? f(v) : v; } : f; }
}

function __asyncValues(o) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var m = o[Symbol.asyncIterator], i;
    return m ? m.call(o) : (o = typeof __values === "function" ? __values(o) : o[Symbol.iterator](), i = {}, verb("next"), verb("throw"), verb("return"), i[Symbol.asyncIterator] = function () { return this; }, i);
    function verb(n) { i[n] = o[n] && function (v) { return new Promise(function (resolve, reject) { v = o[n](v), settle(resolve, reject, v.done, v.value); }); }; }
    function settle(resolve, reject, d, v) { Promise.resolve(v).then(function(v) { resolve({ value: v, done: d }); }, reject); }
}

function __makeTemplateObject(cooked, raw) {
    if (Object.defineProperty) { Object.defineProperty(cooked, "raw", { value: raw }); } else { cooked.raw = raw; }
    return cooked;
}
var __setModuleDefault = Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
};

function __importStar(mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
}

function __importDefault(mod) {
    return (mod && mod.__esModule) ? mod : { default: mod };
}

function __classPrivateFieldGet(receiver, state, kind, f) {
    if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a getter");
    if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot read private member from an object whose class did not declare it");
    return kind === "m" ? f : kind === "a" ? f.call(receiver) : f ? f.value : state.get(receiver);
}

function __classPrivateFieldSet(receiver, state, value, kind, f) {
    if (kind === "m") throw new TypeError("Private method is not writable");
    if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a setter");
    if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot write private member to an object whose class did not declare it");
    return (kind === "a" ? f.call(receiver, value) : f ? f.value = value : state.set(receiver, value)), value;
}

function __classPrivateFieldIn(state, receiver) {
    if (receiver === null || (typeof receiver !== "object" && typeof receiver !== "function")) throw new TypeError("Cannot use 'in' operator on non-object");
    return typeof state === "function" ? receiver === state : state.has(receiver);
}

var tslib_es6 = /*#__PURE__*/Object.freeze({
__proto__: null,
__extends: __extends,
get __assign () { return __assign; },
__rest: __rest,
__decorate: __decorate,
__param: __param,
__esDecorate: __esDecorate,
__runInitializers: __runInitializers,
__propKey: __propKey,
__setFunctionName: __setFunctionName,
__metadata: __metadata,
__awaiter: __awaiter,
__generator: __generator,
__createBinding: __createBinding,
__exportStar: __exportStar,
__values: __values,
__read: __read,
__spread: __spread,
__spreadArrays: __spreadArrays,
__spreadArray: __spreadArray,
__await: __await,
__asyncGenerator: __asyncGenerator,
__asyncDelegator: __asyncDelegator,
__asyncValues: __asyncValues,
__makeTemplateObject: __makeTemplateObject,
__importStar: __importStar,
__importDefault: __importDefault,
__classPrivateFieldGet: __classPrivateFieldGet,
__classPrivateFieldSet: __classPrivateFieldSet,
__classPrivateFieldIn: __classPrivateFieldIn
});

var require$$0 = /*@__PURE__*/getAugmentedNamespace(tslib_es6);

// Copyright (C) 2020 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
Object.defineProperty(service_worker, "__esModule", { value: true });
const tslib_1 = require$$0;
const LOG_TAG = `ServiceWorker: `;
const CACHE_NAME = 'ui-perfetto-dev';
// If the fetch() for the / doesn't respond within 3s, return a cached version.
// This is to avoid that a user waits too much if on a flaky network.
const INDEX_TIMEOUT_MS = 3000;
// Use more relaxed timeouts when caching the subresources for the new version
// in the background.
const INSTALL_TIMEOUT_MS = 30000;
// The install() event is fired:
// 1. On the first visit, when there is no SW installed.
// 2. Every time the user opens the site and the version has been updated (they
//    will get the newer version regardless, unless we hit INDEX_TIMEOUT_MS).
// The latter happens because:
// - / (index.html) is always served from the network (% timeout) and it pulls
//   /v1.2-sha/frontend_bundle.js.
// - /v1.2-sha/frontend_bundle.js will register /service_worker.js?v=v1.2-sha.
// The service_worker.js script itself never changes, but the browser
// re-installs it because the version in the V? query-string argument changes.
// The reinstallation will cache the new files from the v.1.2-sha/manifest.json.
self.addEventListener('install', (event) => {
    const doInstall = () => tslib_1.__awaiter(void 0, void 0, void 0, function* () {
        if (yield caches.has('BYPASS_SERVICE_WORKER')) {
            // Throw will prevent the installation.
            throw new Error(LOG_TAG + 'skipping installation, bypass enabled');
        }
        // Delete old cache entries from the pre-feb-2021 service worker.
        for (const key of yield caches.keys()) {
            if (key.startsWith('dist-')) {
                yield caches.delete(key);
            }
        }
        // The UI should register this as service_worker.js?v=v1.2-sha. Extract the
        // version number and pre-fetch all the contents for the version.
        const match = /\bv=([\w.-]*)/.exec(location.search);
        if (!match) {
            throw new Error('Failed to install. Was epecting a query string like ' +
                `?v=v1.2-sha query string, got "${location.search}" instead`);
        }
        yield installAppVersionIntoCache(match[1]);
        // skipWaiting() still waits for the install to be complete. Without this
        // call, the new version would be activated only when all tabs are closed.
        // Instead, we ask to activate it immediately. This is safe because the
        // subresources are versioned (e.g. /v1.2-sha/frontend_bundle.js). Even if
        // there is an old UI tab opened while we activate() a newer version, the
        // activate() would just cause cache-misses, hence fetch from the network,
        // for the old tab.
        self.skipWaiting();
    });
    event.waitUntil(doInstall());
});
self.addEventListener('activate', (event) => {
    console.info(LOG_TAG + 'activated');
    const doActivate = () => tslib_1.__awaiter(void 0, void 0, void 0, function* () {
        // This makes a difference only for the very first load, when no service
        // worker is present. In all the other cases the skipWaiting() will hot-swap
        // the active service worker anyways.
        yield self.clients.claim();
    });
    event.waitUntil(doActivate());
});
self.addEventListener('fetch', (event) => {
    // The early return here will cause the browser to fall back on standard
    // network-based fetch.
    if (!shouldHandleHttpRequest(event.request)) {
        console.debug(LOG_TAG + `serving ${event.request.url} from network`);
        return;
    }
    event.respondWith(handleHttpRequest(event.request));
});
function shouldHandleHttpRequest(req) {
    // Suppress warning: 'only-if-cached' can be set only with 'same-origin' mode.
    // This seems to be a chromium bug. An internal code search suggests this is a
    // socially acceptable workaround.
    if (req.cache === 'only-if-cached' && req.mode !== 'same-origin') {
        return false;
    }
    const url = new URL(req.url);
    if (url.pathname === '/live_reload')
        return false;
    return req.method === 'GET' && url.origin === self.location.origin;
}
function handleHttpRequest(req) {
    return tslib_1.__awaiter(this, void 0, void 0, function* () {
        if (!shouldHandleHttpRequest(req)) {
            throw new Error(LOG_TAG + `${req.url} shouldn't have been handled`);
        }
        // We serve from the cache even if req.cache == 'no-cache'. It's a bit
        // contra-intuitive but it's the most consistent option. If the user hits the
        // reload button*, the browser requests the "/" index with a 'no-cache' fetch.
        // However all the other resources (css, js, ...) are requested with a
        // 'default' fetch (this is just how Chrome works, it's not us). If we bypass
        // the service worker cache when we get a 'no-cache' request, we can end up in
        // an inconsistent state where the index.html is more recent than the other
        // resources, which is undesirable.
        // * Only Ctrl+R. Ctrl+Shift+R will always bypass service-worker for all the
        // requests (index.html and the rest) made in that tab.
        const cacheOps = { cacheName: CACHE_NAME };
        const url = new URL(req.url);
        if (url.pathname === '/') {
            try {
                console.debug(LOG_TAG + `Fetching live ${req.url}`);
                // The await bleow is needed to fall through in case of an exception.
                return yield fetchWithTimeout(req, INDEX_TIMEOUT_MS);
            }
            catch (err) {
                console.warn(LOG_TAG + `Failed to fetch ${req.url}, using cache.`, err);
                // Fall through the code below.
            }
        }
        else if (url.pathname === '/offline') {
            // Escape hatch to force serving the offline version without attemping the
            // network fetch.
            const cachedRes = yield caches.match(new Request('/'), cacheOps);
            if (cachedRes)
                return cachedRes;
        }
        const cachedRes = yield caches.match(req, cacheOps);
        if (cachedRes) {
            console.debug(LOG_TAG + `serving ${req.url} from cache`);
            return cachedRes;
        }
        // In any other case, just propagate the fetch on the network, which is the
        // safe behavior.
        console.warn(LOG_TAG + `cache miss on ${req.url}, using live network`);
        return fetch(req);
    });
}
function installAppVersionIntoCache(version) {
    return tslib_1.__awaiter(this, void 0, void 0, function* () {
        const manifestUrl = `${version}/manifest.json`;
        try {
            console.log(LOG_TAG + `Starting installation of ${manifestUrl}`);
            yield caches.delete(CACHE_NAME);
            const resp = yield fetchWithTimeout(manifestUrl, INSTALL_TIMEOUT_MS);
            const manifest = yield resp.json();
            const manifestResources = manifest['resources'];
            if (!manifestResources || !(manifestResources instanceof Object)) {
                throw new Error(`Invalid manifest ${manifestUrl} : ${manifest}`);
            }
            const cache = yield caches.open(CACHE_NAME);
            const urlsToCache = [];
            // We use cache:reload to make sure that the index is always current and we
            // don't end up in some cycle where we keep re-caching the index coming from
            // the service worker itself.
            urlsToCache.push(new Request('/', { cache: 'reload', mode: 'same-origin' }));
            for (const [resource, integrity] of Object.entries(manifestResources)) {
                // We use cache: no-cache rather then reload here because the versioned
                // sub-resources are expected to be immutable and should never be
                // ambiguous. A revalidation request is enough.
                const reqOpts = {
                    cache: 'no-cache',
                    mode: 'same-origin',
                    integrity: `${integrity}`,
                };
                urlsToCache.push(new Request(`${version}/${resource}`, reqOpts));
            }
            yield cache.addAll(urlsToCache);
            console.log(LOG_TAG + 'installation completed for ' + version);
        }
        catch (err) {
            console.error(LOG_TAG + `Installation failed for ${manifestUrl}`, err);
            yield caches.delete(CACHE_NAME);
            throw err;
        }
    });
}
function fetchWithTimeout(req, timeoutMs) {
    const url = req.url || `${req}`;
    return new Promise((resolve, reject) => {
        const timerId = setTimeout(() => {
            reject(new Error(`Timed out while fetching ${url}`));
        }, timeoutMs);
        fetch(req).then((resp) => {
            clearTimeout(timerId);
            if (resp.ok) {
                resolve(resp);
            }
            else {
                reject(new Error(`Fetch failed for ${url}: ${resp.status} ${resp.statusText}`));
            }
        }, reject);
    });
}

return service_worker;

})();
//# sourceMappingURL=service_worker.js.map

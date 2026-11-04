// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dtd/dtd.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:vm_service/vm_service.dart';

import '../common.dart';
import '../deeplink/deeplink_manager.dart';
import '../devtools_api.dart';
import '../extensions/extension_enablement.dart';
import '../extensions/extension_manager.dart';
import '../service/service.dart';
import '../service_utils.dart';
import '../utils/file_utils.dart';
import 'devtools_store.dart';
import 'file_system.dart';
import 'flutter_store.dart';

part 'handlers/_app_size.dart';
part 'handlers/_deeplink.dart';
part 'handlers/_devtools_extensions.dart';
part 'handlers/_dtd.dart';
part 'handlers/_preferences.dart';
part 'handlers/_release_notes.dart';
part 'handlers/_storage.dart';
part 'handlers/_survey.dart';
part 'handlers/_vm_service.dart';

/// The DevTools server API.
///
/// This defines endpoints that serve all requests that come in over api/.
class ServerApi {
  static const logsKey = 'logs';
  static const errorKey = 'error';

  static const _postMethod = 'POST';
  static const _optionsMethod = 'OPTIONS';
  static const _originHeader = 'origin';
  static const _secFetchSiteHeader = 'sec-fetch-site';
  static const _crossSiteSecFetchSite = 'cross-site';
  static const _allowedSecFetchSites = {'same-origin', 'same-site', 'none'};

  /// Determines whether or not [request] is an API call.
  static bool canHandle(shelf.Request request) {
    return request.url.path.startsWith(apiPrefix);
  }

  /// Validates [request] to mitigate CSRF, DNS rebinding, and cross-origin
  /// attacks before dispatching to any [ServerApi] handler.
  ///
  /// Returns a [shelf.Response] if the request is rejected, or `null` if the
  /// request is valid.
  static shelf.Response? _validateRequest(
    shelf.Request request,
    ServerApi api,
  ) {
    final method = request.method.toUpperCase();
    if (method != _postMethod && method != _optionsMethod) {
      return shelf.Response(
        HttpStatus.methodNotAllowed,
        body: 'Method Not Allowed: ${request.method}',
      );
    }

    final hostHeaders = request.headersAll[HttpHeaders.hostHeader];
    if (hostHeaders != null && hostHeaders.length > 1) {
      return api.forbidden('Invalid Host header');
    }
    final hostHeader = request.headers[HttpHeaders.hostHeader];
    final host = hostHeader != null
        ? _extractHostFromHeader(hostHeader)
        : request.requestedUri.host;
    if (host == null ||
        !_isLoopbackHost(host) ||
        !_isLoopbackHost(request.requestedUri.host)) {
      return api.forbidden('Invalid Host header');
    }

    final originHeaders = request.headersAll[_originHeader];
    if (originHeaders != null && originHeaders.length > 1) {
      return api.forbidden('Invalid Origin header');
    }
    final originHeader = request.headers[_originHeader];
    if (originHeader != null) {
      final originUri = Uri.tryParse(originHeader.trim());
      if (originUri == null ||
          originUri.userInfo.isNotEmpty ||
          !_isLoopbackHost(originUri.host)) {
        return api.forbidden('Invalid Origin header');
      }
    }

    final secFetchSite = request.headers[_secFetchSiteHeader]
        ?.trim()
        .toLowerCase();
    // Allow `cross-site` when a validated loopback `Origin` header is present
    // (e.g. `http://localhost:<port>` calling `http://127.0.0.1:<port>` in
    // `debug_devtools_server` mode).
    if (secFetchSite != null &&
        !_allowedSecFetchSites.contains(secFetchSite) &&
        !(secFetchSite == _crossSiteSecFetchSite && originHeader != null)) {
      return api.forbidden('Cross-site requests are not allowed');
    }

    return null;
  }

  /// Extracts the host component from an HTTP `Host` header value, or returns
  /// `null` if the header is malformed.
  static String? _extractHostFromHeader(String hostHeader) {
    final trimmed = hostHeader.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == '::1') return '::1';
    final parsed = Uri.tryParse('http://$trimmed');
    if (parsed == null ||
        parsed.userInfo.isNotEmpty ||
        parsed.path.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        parsed.host.isEmpty) {
      return null;
    }
    return parsed.host;
  }

  /// Returns whether [host] is a loopback host
  /// (`localhost`, `127.x.x.x`, or `::1`).
  static bool _isLoopbackHost(String host) =>
      host == 'localhost' ||
      (InternetAddress.tryParse(host)?.isLoopback ?? false);

  /// Handles all requests.
  ///
  /// To override an API call, pass in a subclass of [ServerApi].
  static FutureOr<shelf.Response> handle(
    shelf.Request request, {
    required ExtensionsManager extensionsManager,
    required DeeplinkManager deeplinkManager,
    ServerApi? api,
    DtdInfo? dtd,
  }) {
    api ??= ServerApi();
    final validationErrorResponse = _validateRequest(request, api);
    if (validationErrorResponse != null) {
      return validationErrorResponse;
    }
    if (request.method.toUpperCase() == _optionsMethod) {
      // Respond to CORS preflight requests (e.g. from `debug_devtools_server`
      // running on another loopback port). `Access-Control-Allow-Origin` is
      // intentionally omitted here and controlled by the server's `--disable-cors`
      // configuration.
      return shelf.Response(
        HttpStatus.noContent,
        headers: const {
          HttpHeaders.accessControlAllowMethodsHeader:
              '$_postMethod, $_optionsMethod',
          HttpHeaders.accessControlAllowHeadersHeader: devToolsRequestHeader,
        },
      );
    }
    final queryParams = request.requestedUri.queryParameters;
    switch (request.url.path) {
      case apiNotifyForVmServiceConnection:
        return VmServiceHandler.handleNotifyForVmServiceConnection(
          api,
          queryParams,
          dtd,
        );

      // ----- Flutter Tool GA store. -----
      case apiGetFlutterGAClientId:
        return _encodeResponse(
          fileSystem.flutterStoreExists ? _flutterStore.flutterClientId : '',
          api: api,
        );

      // ----- Preferences api. -----
      case PreferencesApi.getPreferenceValue:
        return _PreferencesApiHandler.getPreferenceValue(
          api,
          queryParams,
          _devToolsStore,
        );

      case PreferencesApi.setPreferenceValue:
        return _PreferencesApiHandler.setPreferenceValue(
          api,
          queryParams,
          _devToolsStore,
        );

      // ----- DevTools survey api. -----

      case SurveyApi.setActiveSurvey:
        return _SurveyHandler.setActiveSurvey(api, queryParams, _devToolsStore);

      case SurveyApi.getSurveyActionTaken:
        return _SurveyHandler.getSurveyActionTaken(api, _devToolsStore);

      case SurveyApi.setSurveyActionTaken:
        return _SurveyHandler.setSurveyActionTaken(api, _devToolsStore);

      case SurveyApi.getSurveyShownCount:
        return _SurveyHandler.getSurveyShownCount(api, _devToolsStore);

      case SurveyApi.incrementSurveyShownCount:
        return _SurveyHandler.incrementSurveyShownCount(api, _devToolsStore);

      // ----- Release notes api. -----

      case ReleaseNotesApi.getLastReleaseNotesVersion:
        return _ReleaseNotesHandler.getLastReleaseNotesVersion(
          api,
          _devToolsStore,
        );

      case ReleaseNotesApi.setLastReleaseNotesVersion:
        return _ReleaseNotesHandler.setLastReleaseNotesVersion(
          api,
          queryParams,
          _devToolsStore,
        );

      // ----- App size api. -----

      case AppSizeApi.getBaseAppSizeFile:
        return _AppSizeHandler.getBaseAppSizeFile(api, queryParams);

      case AppSizeApi.getTestAppSizeFile:
        return _AppSizeHandler.getTestAppSizeFile(api, queryParams);

      // ----- Extensions api. -----

      case ExtensionsApi.apiServeAvailableExtensions:
        return _ExtensionsApiHandler.handleServeAvailableExtensions(
          api,
          queryParams,
          extensionsManager,
          dtd,
        );

      case ExtensionsApi.apiExtensionEnabledState:
        return _ExtensionsApiHandler.handleExtensionEnabledState(
          api,
          queryParams,
        );

      // ----- deeplink api. -----

      case DeeplinkApi.androidBuildVariants:
        return _DeeplinkApiHandler.handleAndroidBuildVariants(
          api,
          queryParams,
          deeplinkManager,
        );

      case DeeplinkApi.androidAppLinkSettings:
        return _DeeplinkApiHandler.handleAndroidAppLinkSettings(
          api,
          queryParams,
          deeplinkManager,
        );

      case DeeplinkApi.iosBuildOptions:
        return _DeeplinkApiHandler.handleIosBuildOptions(
          api,
          queryParams,
          deeplinkManager,
        );

      case DeeplinkApi.iosUniversalLinkSettings:
        return _DeeplinkApiHandler.handleIosUniversalLinkSettings(
          api,
          queryParams,
          deeplinkManager,
        );

      // ----- DTD api. -----

      case DtdApi.apiGetDtdUri:
        return _DtdApiHandler.handleGetDtdUri(api, dtd);

      // ----- Unimplemented. -----

      default:
        return api.notImplemented();
    }
  }

  static shelf.Response _encodeResponse(
    Object? object, {
    required ServerApi api,
  }) {
    return api.success(json.encode(object));
  }

  static Map<String, Object?> _wrapWithLogs(
    Map<String, Object?> result,
    List<String> logs,
  ) {
    result[logsKey] = logs;
    return result;
  }

  static shelf.Response? _checkRequiredParameters(
    List<String> expectedParams, {
    required Map<String, String> queryParams,
    required ServerApi api,
    required String requestName,
  }) {
    final missing = expectedParams.where(
      (param) => !queryParams.containsKey(param),
    );
    return missing.isNotEmpty
        ? api.badRequest(
            '[$requestName] missing required query parameters: '
            '${missing.toList()}',
          )
        : null;
  }

  /// Accessing DevTools store file e.g., `~/.flutter-devtools/.devtools`.
  static final _devToolsStore = DevToolsUsage();

  /// Accessing Flutter store file e.g., `~/.flutter`.
  static final _flutterStore = FlutterStore();

  static DevToolsUsage get devToolsPreferences => _devToolsStore;

  /// Provides read and write access to DevTools options files
  /// (e.g. `path/to/app/root/devtools_options.yaml`).
  static final _devToolsOptions = DevToolsOptions();

  /// Logs a page view in the DevTools server.
  ///
  /// In the open-source version of DevTools, Google Analytics handles this
  /// without any need to involve the server.
  shelf.Response logScreenView() => notImplemented();

  /// A [shelf.Response] for API calls that succeeded.
  ///
  /// The response optionally contains a single String [value].
  shelf.Response success([String? value]) => shelf.Response.ok(value);

  /// A [shelf.Response] for API calls that are forbidden for the current state
  /// of the server.
  shelf.Response forbidden([String? reason]) =>
      shelf.Response.forbidden(reason);

  /// A [shelf.Response] for API calls that encountered a request problem e.g.,
  /// setActiveSurvey not called.
  ///
  /// This is a 400 Bad Request response.
  shelf.Response badRequest([String? error]) {
    if (error != null) print(error);
    return shelf.Response(HttpStatus.badRequest, body: error);
  }

  /// A [shelf.Response] for API calls that encountered a server error e.g.,
  /// setActiveSurvey not called.
  ///
  /// This is a 500 Internal Server Error response.
  shelf.Response serverError([String? error, List<String>? logs]) {
    if (error != null) print(error);
    return shelf.Response(
      HttpStatus.internalServerError,
      body: error != null || logs != null
          ? jsonEncode({errorKey: ?error, logsKey: ?logs})
          : null,
    );
  }

  /// A [shelf.Response] for API calls that have not been implemented in this
  /// server.
  ///
  /// This is a no-op 204 No Content response because returning 404 Not Found
  /// creates unnecessary noise in the console.
  shelf.Response notImplemented() => shelf.Response(HttpStatus.noContent);
}

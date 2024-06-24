import '../../../devtools_app.dart';
import '../../shared/analytics/constants.dart';

/// Builds a HAR (HTTP Archive) object from a list of HTTP requests.
///
/// The HAR format is a JSON-based format used for logging a web browser's
/// interaction with a site. It is useful for web performance analysis and
/// debugging. This function constructs the HAR object based on the 1.2
/// specification.
///
/// For more details on the HAR format, see the [HAR 1.2 Specification](https://github.com/ahmadnassri/har-spec/blob/master/versions/1.2.md).
///
/// Parameters:
/// - [httpRequests]: A list of DartIOHttpRequestData data.
///
/// Returns:
/// - A Map representing the HAR object.
Map<String, dynamic> buildHar(List<DartIOHttpRequestData> httpRequests) {
// Build the creator
  final creator = {
    NetworkEventKeys.name: NetworkEventDefaults.creatorName,
    NetworkEventKeys.creatorVersion: NetworkEventDefaults.creatorVersion,
  };

// Build the pages
  final pages = [
    {
      NetworkEventKeys.startedDateTime:
          httpRequests.first.startTimestamp.toUtc().toIso8601String(),
      NetworkEventKeys.id: NetworkEventDefaults.id,
      NetworkEventKeys.title: NetworkEventDefaults.title,
      NetworkEventKeys.pageTimings: {
        NetworkEventKeys.onContentLoad: NetworkEventDefaults.onContentLoad,
        NetworkEventKeys.onLoad: NetworkEventDefaults.onLoad,
      },
    },
  ];

// Build the entries
  final entries = httpRequests.map((e) {
    final requestCookies = e.requestCookies.map((cookie) {
      return {
        NetworkEventKeys.name: cookie.name,
        NetworkEventKeys.value: cookie.value,
        'path': cookie.path,
        'domain': cookie.domain,
        'expires': cookie.expires?.toUtc().toIso8601String(),
        'httpOnly': cookie.httpOnly,
        'secure': cookie.secure,
      };
    }).toList();

    final requestHeaders = e.requestHeaders?.entries.map((header) {
      var value = header.value;
      if (value is List) {
        value = value.first;
      }
      return {
        NetworkEventKeys.name: header.key,
        NetworkEventKeys.value: value,
      };
    }).toList();

    final queryString = Uri.parse(e.uri).queryParameters.entries.map((param) {
      return {
        NetworkEventKeys.name: param.key,
        NetworkEventKeys.value: param.value,
      };
    }).toList();

    final responseCookies = e.responseCookies.map((cookie) {
      return {
        NetworkEventKeys.name: cookie.name,
        NetworkEventKeys.value: cookie.value,
        'path': cookie.path,
        'domain': cookie.domain,
        'expires': cookie.expires?.toUtc().toIso8601String(),
        'httpOnly': cookie.httpOnly,
        'secure': cookie.secure,
      };
    }).toList();

    final responseHeaders = e.responseHeaders?.entries.map((header) {
      var value = header.value;
      if (value is List) {
        value = value.first;
      }
      return {
        NetworkEventKeys.name: header.key,
        NetworkEventKeys.value: value,
      };
    }).toList();

    return {
      NetworkEventKeys.pageref: NetworkEventDefaults.id,
      NetworkEventKeys.startedDateTime:
          e.startTimestamp.toUtc().toIso8601String(),
      NetworkEventKeys.time: e.duration?.inMilliseconds,
      NetworkEventKeys.request: {
        NetworkEventKeys.method: e.method.toUpperCase(),
        NetworkEventKeys.url: e.uri.toString(),
        NetworkEventKeys.httpVersion: NetworkEventDefaults.httpVersion,
        NetworkEventKeys.cookies: requestCookies,
        NetworkEventKeys.headers: requestHeaders,
        NetworkEventKeys.queryString: queryString,
        NetworkEventKeys.postData: {
          NetworkEventKeys.mimeType: e.contentType,
          NetworkEventKeys.text: e.requestBody,
        },
        NetworkEventKeys.headersSize: NetworkEventDefaults.headersSize,
        NetworkEventKeys.bodySize: NetworkEventDefaults.bodySize,
      },
      NetworkEventKeys.response: {
        NetworkEventKeys.status: e.status,
        NetworkEventKeys.statusText: '',
        NetworkEventKeys.httpVersion: NetworkEventDefaults.responseHttpVersion,
        NetworkEventKeys.cookies: responseCookies,
        NetworkEventKeys.headers: responseHeaders,
        NetworkEventKeys.content: {
          NetworkEventKeys.size: e.responseBody?.length,
          NetworkEventKeys.mimeType: e.type,
          NetworkEventKeys.text: e.responseBody,
        },
        NetworkEventKeys.redirectURL: '',
        NetworkEventKeys.headersSize: NetworkEventDefaults.headersSize,
        NetworkEventKeys.bodySize: NetworkEventDefaults.bodySize,
      },
      NetworkEventKeys.cache: {},
      NetworkEventKeys.timings: {
        NetworkEventKeys.blocked: NetworkEventDefaults.blocked,
        NetworkEventKeys.dns: NetworkEventDefaults.dns,
        NetworkEventKeys.connect: NetworkEventDefaults.connect,
        NetworkEventKeys.send: NetworkEventDefaults.send,
        NetworkEventKeys.wait: e.duration!.inMilliseconds - 2,
        NetworkEventKeys.receive: NetworkEventDefaults.receive,
        NetworkEventKeys.ssl: NetworkEventDefaults.ssl,
      },
      NetworkEventKeys.serverIPAddress: NetworkEventDefaults.serverIPAddress,
      NetworkEventKeys.connection: e.hashCode.toString(),
      NetworkEventKeys.comment: '',
    };
  }).toList();

// Assemble the final HAR object
  return {
    NetworkEventKeys.log: {
      NetworkEventKeys.version: NetworkEventDefaults.logVersion,
      NetworkEventKeys.creator: creator,
      NetworkEventKeys.pages: pages,
      NetworkEventKeys.entries: entries,
    },
  };
}

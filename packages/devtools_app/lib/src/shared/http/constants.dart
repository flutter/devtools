// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum HttpRequestDataKeys {
  connectionInfo,
  remoteAddress,
  localPort,
  contentLength,
  startedDateTime,
  time,
  request,
  method,
  url,
  httpVersion,
  cookies,
  headers,
  queryString,
  postData,
  mimeType,
  text,
  headersSize,
  bodySize,
  followRedirects,
  maxRedirects,
  persistentConnection,
  proxyDetails,
  proxy,
  type,
  error,
  response,
  status,
  statusCode,
  statusText,
  redirects,
  redirectURL,
  cache,
  timings,
  blocked,
  dns,
  connect,
  send,
  wait,
  receive,
  ssl,
  connection,
  comment,
  isolateId,
  uri,
  id,
  startTime,
  events,
  timestamp,
  event,
  compressionState,
  isRedirect,
  reasonPhrase,
  queryParameters,
  content,
  size,
  connectionId,
  requestBody,
  responseBody,
  endTime,
  arguments,
  host,
  username,
  isDirect,
}

enum HttpRequestDataValues { json }

class HttpRequestDataDefaults {
  static const none = 'None';
  static const error = 'Error';
  static const httpVersion = 'HTTP/2.0';
  static const json = 'json';
  static const httpProfileRequest = '@HttpProfileRequest';
}

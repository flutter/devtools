// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum NetworkEventKeys {
  log,
  version,
  creator,
  name,
  creatorVersion,
  pages,
  startedDateTime,
  id,
  title,
  pageTimings,
  onContentLoad,
  onLoad,
  entries,
  pageref,
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
  response,
  status,
  statusText,
  content,
  size,
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
  serverIPAddress,
  connection,
  comment,
  value,
}

class NetworkEventDefaults {
  static const logVersion = '1.2';
  static const creatorName = 'devtools';
  static const onContentLoad = -1;
  static const onLoad = -1;
  static const httpVersion = 'HTTP/1.1';
  static const responseHttpVersion = 'http/2.0';
  static const blocked = -1;
  static const dns = -1;
  static const connect = -1;
  static const send = 1;
  static const receive = 1;
  static const ssl = -1;
}

class NetworkEventCustomFieldKeys {
  static const isolateId = '_isolateId';
  static const id = '_id';
  static const startTime = '_startTime';
  static const events = '_events';
}

enum NetworkEventCustomFieldRemappedKeys {
  isolateId,
  id,
  startTime,
  events,
}

// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// Fixture for a cancelled HTTP request:
// - isRequestComplete: true  (client finished sending)
// - isResponseComplete: false (no response arrived)
// - response: null
// - endTime is set (request is done, not still in-flight)

const httpGetCancelledJson = <String, dynamic>{
  'id': '99',
  'isolateId': 'isolates/123',
  'method': 'GET',
  'uri': 'https://jsonplaceholder.typicode.com/albums/1',
  'events': <dynamic>[
    {'timestamp': 6326379935, 'event': 'Request cancelled by client'},
  ],
  'startTime': 6326279935,  // microseconds
  'endTime': 6326479935,    // 200ms later
  'request': <String, dynamic>{
    'headers': <String, dynamic>{},
    'compressionState': 'HttpClientRequestCompressionState.notCompressed',
    'connectionInfo': null,
    'contentLength': 0,
    'cookies': <dynamic>[],
    'followRedirects': true,
    'maxRedirects': 5,
    'method': 'GET',
    'persistentConnection': true,
    'uri': 'https://jsonplaceholder.typicode.com/albums/1',
  },
  'response': null,   // ← key: no response
};

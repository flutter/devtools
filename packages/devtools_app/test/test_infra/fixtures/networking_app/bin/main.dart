// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert' show json;
import 'dart:developer';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

void main() async {
  final testServer = await _bindTestServer();
  registerMakeRequestExtension(testServer);
}

void registerMakeRequestExtension(io.HttpServer testServer) {
  final client = _HttpClient(testServer.port);
  registerExtension('ext.networking_app.makeRequest', (_, parameters) async {
    final hasBody = bool.tryParse(parameters['hasBody'] ?? 'false') ?? false;
    final requestType = parameters['requestType'];
    if (requestType == null) {
      return ServiceExtensionResponse.error(
        ServiceExtensionResponse.invalidParams,
        json.encode({'error': 'Missing "requestType" field'}),
      );
    }
    switch (requestType) {
      case 'get':
        client.get();
      case 'post':
        client.post(hasBody: hasBody);
      case 'put':
        client.put(hasBody: hasBody);
      case 'delete':
        client.delete(hasBody: hasBody);
      case 'dioGet':
        client.dioGet();
      case 'dioPost':
        client.dioPost(hasBody: hasBody);
      case 'packageHttpGet':
        client.packageHttpGet(hasBody: hasBody);
      case 'packageHttpPost':
        client.packageHttpPost(hasBody: hasBody);
      case 'packageHttpPostStreamed':
        client.packageHttpPostStreamed();
      default:
        return ServiceExtensionResponse.error(
          ServiceExtensionResponse.invalidParams,
          json.encode({'error': 'Unknown requestType: "$requestType"'}),
        );
    }
    return ServiceExtensionResponse.result(json.encode({'type': 'success'}));
  });

  registerExtension('ext.networking_app.exit', (_, parameters) async {
    unawaited(
      Future.delayed(const Duration(milliseconds: 200)).then((_) => io.exit(0)),
    );
    return ServiceExtensionResponse.result(json.encode({'type': 'success'}));
  });
}

/// Binds a "test" HTTP server to an available port.
///
/// This server can receive requests, and responds to them.
Future<io.HttpServer> _bindTestServer() async {
  final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.write('fallthrough');
    if (request.uri.path.contains('complete/')) {
      await request.response.close();
    }
  });
  return server;
}

// TODO(https://github.com/flutter/devtools/issues/8223): Test support for
// WebSockets.
// TODO(https://github.com/flutter/devtools/issues/4829): Test support for the
// cupertino_http package and the cronet_http package.

class _HttpClient {
  _HttpClient(int testServerPort)
    : _uri = Uri.http('127.0.0.1:$testServerPort', '/');

  final Uri _uri;

  final _client = io.HttpClient();

  final _dio = Dio();

  void close() {
    _client.close(force: true);
    _dio.close(force: true);
  }

  void get() async {
    print('Sending GET...');
    final request = await _client.getUrl(_uri);
    print('Sent GET: $request');
    // No body.
    final response = await request.done;
    print('Received GET response: $response');
  }

  void post({bool hasBody = false}) async {
    print('Sending POST...');
    final request = await _client.postUrl(_uri);
    print('Sent POST: $request');
    if (hasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    print('Received POST response: $response');
  }

  void put({bool hasBody = false}) async {
    print('Sending PUT...');
    final request = await _client.putUrl(_uri);
    print('Sent PUT: $request');
    if (hasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    print('Received POST response: $response');
  }

  void delete({bool hasBody = false}) async {
    print('Sending DELETE...');
    final request = await _client.deleteUrl(_uri);
    print('Sent DELETE: $request');
    if (hasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    print('Received DELETE response: $response');
  }

  void packageHttpGet({bool hasBody = false}) async {
    print('Sending package:http GET...');
    // No body.
    final response = await http.get(_uri);
    print('Received package:http GET response: $response');
  }

  void packageHttpPost({bool hasBody = false}) async {
    print('Sending package:http POST...');
    final response = await http.post(
      _uri,
      body: hasBody ? {'name': 'doodle', 'color': 'blue'} : null,
    );
    print('Received package:http POST response: $response');
  }

  void packageHttpPostStreamed() async {
    print('Sending streamed package:http POST...');
    final request = http.StreamedRequest('POST', _uri)
      ..contentLength = 20
      ..sink.add([11, 12, 13, 14, 15, 16, 17, 18, 19, 20])
      ..sink.add([21, 22, 23, 24, 25, 26, 27, 28, 29, 30]);
    unawaited(request.sink.close());
    final response = await request.send();

    print('Received package:http POST response: $response');
  }

  void dioGet() async {
    print('Sending Dio GET...');
    // No body.
    final response = await _dio.getUri(_uri);
    print('Received Dio GET response: $response');
  }

  void dioPost({bool hasBody = false}) async {
    print('Sending Dio POST...');
    final response = await _dio.postUri(
      _uri,
      data: hasBody ? {'a': 'b', 'c': 'd'} : null,
    );
    print('Received Dio POST response: $response');
  }
}

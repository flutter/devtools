// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert' show json;
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

void main() async {
  final testServer = await _bindTestServer();
  await _bindControlServer(testServer);
}

/// Binds a "test" HTTP server to an available port.
///
/// This server can receive requests, and responds to them.
Future<io.HttpServer> _bindTestServer() async {
  final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    request.response.write('fallthrough');
    if (request.uri.path.contains('complete/')) {
      request.response.close();
    }
  });
  return server;
}

/// Binds a "control" HTTP server to an available port.
///
/// This server has an HTTP client, and can receive commands for that client to
/// send requests to the "test" HTTP server.
Future<io.HttpServer> _bindControlServer(io.HttpServer testServer) async {
  final client = _HttpClient(testServer.port);

  final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
  print(json.encode({'controlPort': server.port}));
  server.listen((request) {
    request.response.headers
      ..add('Access-Control-Allow-Origin', '*')
      ..add('Access-Control-Allow-Methods', 'POST,GET,DELETE,PUT,OPTIONS');
    final path = request.uri.path;
    final hasBody = path.contains('/body/');
    request.response
      ..statusCode = 200
      ..write('received request at: "$path"');

    if (path.startsWith('/get/')) {
      client.get();
    } else if (path.startsWith('/post/')) {
      client.post(hasBody: hasBody);
    } else if (path.startsWith('/put/')) {
      client.put(hasBody: hasBody);
    } else if (path.startsWith('/delete/')) {
      client.delete(hasBody: hasBody);
    } else if (path.startsWith('/dio/get/')) {
      client.dioGet();
    } else if (path.startsWith('/dio/post/')) {
      client.dioPost(hasBody: hasBody);
    } else if (path.startsWith('/packageHttp/post/')) {
      client.packageHttpPost(hasBody: hasBody);
    } else if (path.startsWith('/packageHttp/postStreamed/')) {
      client.packageHttpPostStreamed();
    }
    request.response.close();
  });
  return server;
}

// TODO WebSocket
// TODO package:http - BrowserClient - https://pub.dev/documentation/http/latest/browser_client/BrowserClient-class.html
// TODO cupertino_http - https://pub.dev/packages/cupertino_http
// TODO cronet_http - https://pub.dev/packages/cronet_http
// TDOO fetch_client? https://pub.dev/packages/fetch_client

class _HttpClient {
  _HttpClient(int testServerPort)
    : _uri = Uri.http('127.0.0.1:$testServerPort', '/');

  final Uri _uri;

  final client = io.HttpClient();

  final _dio = Dio();

  void get() async {
    print('Sending GET...');
    final request = await client.getUrl(_uri);
    print('Sent GET: $request');
    // No body.
    final response = await request.done;
    print('Received GET response: $response');
  }

  void post({bool hasBody = false}) async {
    print('Sending POST...');
    final request = await client.postUrl(_uri);
    print('Sent POST: $request');
    if (hasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    print('Received POST response: $response');
  }

  void put({bool hasBody = false}) async {
    print('Sending PUT...');
    final request = await client.putUrl(_uri);
    print('Sent PUT: $request');
    if (hasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    print('Received POST response: $response');
  }

  void delete({bool hasBody = false}) async {
    print('Sending DELETE...');
    final request = await client.deleteUrl(_uri);
    print('Sent DELETE: $request');
    if (hasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    print('Received DELETE response: $response');
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
    final request =
        http.StreamedRequest('POST', _uri)
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

// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../constants.dart';

class NetworkEvent {
  static const networkDownloadHar = 'networkDownloadHar';
}

class NetworkEventKeys {
  static const log = 'log';
  static const version = 'version';
  static const creator = 'creator';
  static const name = 'name';
  static const creatorVersion = 'version';
  static const pages = 'pages';
  static const startedDateTime = 'startedDateTime';
  static const id = 'id';
  static const title = 'title';
  static const pageTimings = 'pageTimings';
  static const onContentLoad = 'onContentLoad';
  static const onLoad = 'onLoad';
  static const entries = 'entries';
  static const pageref = 'pageref';
  static const time = 'time';
  static const request = 'request';
  static const method = 'method';
  static const url = 'url';
  static const httpVersion = 'httpVersion';
  static const cookies = 'cookies';
  static const headers = 'headers';
  static const queryString = 'queryString';
  static const postData = 'postData';
  static const mimeType = 'mimeType';
  static const text = 'text';
  static const headersSize = 'headersSize';
  static const bodySize = 'bodySize';
  static const response = 'response';
  static const status = 'status';
  static const statusText = 'statusText';
  static const content = 'content';
  static const size = 'size';
  static const redirectURL = 'redirectURL';
  static const cache = 'cache';
  static const timings = 'timings';
  static const blocked = 'blocked';
  static const dns = 'dns';
  static const connect = 'connect';
  static const send = 'send';
  static const wait = 'wait';
  static const receive = 'receive';
  static const ssl = 'ssl';
  static const serverIPAddress = 'serverIPAddress';
  static const connection = 'connection';
  static const comment = 'comment';
  static const value = 'value';
}

class NetworkEventDefaults {
  static const logVersion = '1.2';
  static const creatorName = 'devtools';
  static const creatorVersion = '0.0.2';
  static const id = 'page_0';
  static const title = 'FlutterCapture';
  static const onContentLoad = -1;
  static const onLoad = -1;
  static const httpVersion = 'HTTP/1.1';
  static const responseHttpVersion = 'http/2.0';
  static const headersSize = -1;
  static const bodySize = -1;
  static const blocked = -1;
  static const dns = -1;
  static const connect = -1;
  static const send = 1;
  static const receive = 1;
  static const ssl = -1;
  static const serverIPAddress = '10.0.0.1';
}

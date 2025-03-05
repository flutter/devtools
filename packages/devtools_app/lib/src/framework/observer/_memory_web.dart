// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

/// Estimates the memory usage of the DevTools web aplication, including all
/// iFrames and workers.
///
/// See https://developer.mozilla.org/en-US/docs/Web/API/Performance/measureUserAgentSpecificMemory.
Future<int?> measureMemoryUsageInBytes() async {
  // Use of this API requires a secure context and cross origin isolation.
  if (window.isSecureContext && window.crossOriginIsolated) {
    final memory = await window.performance.measureUserAgentSpecificMemory();
    return memory?.bytes;
  }
  return null;
}

extension on Performance {
  @JS('measureUserAgentSpecificMemory')
  external JSPromise<_UserAgentSpecificMemory> _measureUserAgentSpecificMemory();

  Future<_UserAgentSpecificMemory>? measureUserAgentSpecificMemory() =>
      has('measureUserAgentSpecificMemory')
          ? _measureUserAgentSpecificMemory().toDart
          : null;
}

@JS()
extension type _UserAgentSpecificMemory._(JSObject _) implements JSObject {
  external int get bytes;

  external JSArray<_UserAgentSpecificMemoryBreakdownElement> get breakdown;
}

@JS()
extension type _UserAgentSpecificMemoryBreakdownElement._(JSObject _)
    implements JSObject {
  external JSArray<_UserAgentSpecificMemoryBreakdownAttributionElement>
  get attribution;

  external int get bytes;

  external JSArray<JSString> get types;
}

@JS()
extension type _UserAgentSpecificMemoryBreakdownAttributionElement._(JSObject _)
    implements JSObject {
  external _UserAgentSpecificMemoryBreakdownAttributionContainerElement?
  get container;

  external String get scope;

  external String get url;
}

@JS()
extension type _UserAgentSpecificMemoryBreakdownAttributionContainerElement._(
  JSObject _
)
    implements JSObject {
  external String get id;

  external String get url;
}

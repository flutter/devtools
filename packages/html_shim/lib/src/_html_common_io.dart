// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This library is direct fork of functionality from dart:html exposing the
/// same APIs with an implementation that always throws exceptions.
library html_common;

import 'dart:async';

/// All calls to dart:html should bottom out to calling this method.
dynamic unsupported() =>
    throw UnsupportedError('dart:html is not supported on Flutter');

Map<String, dynamic> convertNativeToDart_Dictionary(object) {
  unsupported();
}

/// Converts a flat Dart map into a JavaScript object with properties.
convertDartToNative_Dictionary(Map dict, [void postCreate(Object f)]) {
  unsupported();
}

/**
 * Ensures that the input is a JavaScript Array.
 *
 * Creates a new JavaScript array if necessary, otherwise returns the original.
 */
List convertDartToNative_StringArray(List<String> input) {
  // TODO(sra).  Implement this.
  return input;
}

DateTime convertNativeToDart_DateTime(date) {
  unsupported();
}

convertDartToNative_DateTime(DateTime date) {
  unsupported();
}

convertDartToNative_PrepareForStructuredClone(value) => unsupported();

convertNativeToDart_AcceptStructuredClone(object, {mustCopy: false}) =>
    unsupported();

bool isJavaScriptDate(value) => unsupported();
bool isJavaScriptRegExp(value) => unsupported();
bool isJavaScriptArray(value) => unsupported();
bool isJavaScriptSimpleObject(value) {
  var proto = unsupported();
  return unsupported();
}

bool isImmutableJavaScriptArray(value) => unsupported();
bool isJavaScriptPromise(value) => unsupported();

Future convertNativePromiseToDartFuture(promise) {
  unsupported();
}

const String _serializedScriptValue = 'num|String|bool|'
    'JSExtendableArray|=Object|'
    'Blob|File|NativeByteBuffer|NativeTypedData|MessagePort'
// TODO(sra): Add Date, RegExp.
    ;
const annotation_Creates_SerializedScriptValue = const Object();
const annotation_Returns_SerializedScriptValue = const Object();

/// Tells the optimizing compiler to always inline the annotated method.
class ForceInline {
  const ForceInline();
}

class _NotNull {
  const _NotNull();
}

/// Marks a variable or API to be non-nullable.
/// ****CAUTION******
/// This is currently unchecked, and hence should never be used
/// on any public interface where user code could subclass, implement,
/// or otherwise cause the contract to be violated.
/// TODO(leafp): Consider adding static checking and exposing
/// this to user code.
const notNull = _NotNull();

/// Marks a generic function or static method API to be not reified.
/// ****CAUTION******
/// This is currently unchecked, and hence should be used very carefully for
/// internal SDK APIs only.
class NoReifyGeneric {
  const NoReifyGeneric();
}

/// Enables/disables reification of functions within the body of this function.
/// ****CAUTION******
/// This is currently unchecked, and hence should be used very carefully for
/// internal SDK APIs only.
class ReifyFunctionTypes {
  final bool value;
  const ReifyFunctionTypes(this.value);
}

class _NullCheck {
  const _NullCheck();
}

/// Annotation indicating the parameter should default to the JavaScript
/// undefined constant.
const undefined = _Undefined();

class _Undefined {
  const _Undefined();
}

/// Tells the development compiler to check a variable for null at its
/// declaration point, and then to assume that the variable is non-null
/// from that point forward.
/// ****CAUTION******
/// This is currently unchecked, and hence will not catch re-assignments
/// of a variable with null
const nullCheck = _NullCheck();

/// Tells the optimizing compiler that the annotated method cannot throw.
/// Requires @NoInline() to function correctly.
class NoThrows {
  const NoThrows();
}

/// Tells the optimizing compiler to not inline the annotated method.
class NoInline {
  const NoInline();
}

/// Marks a class as native and defines its JavaScript name(s).
class Native {
  final String name;
  const Native(this.name);
}

class JsPeerInterface {
  /// The JavaScript type that we should match the API of.
  /// Used for classes where Dart subclasses should be callable from JavaScript
  /// matching the JavaScript calling conventions.
  final String name;
  const JsPeerInterface({this.name});
}

class Unstable {
  const Unstable();
}

class JSName {
  const JSName(this.name);
  final String name;
}

class DomName {
  const DomName(this.name);
  final String name;
}

class Returns {
  const Returns(this.type);
  final String type;
}

class Creates {
  const Creates(this.type);
  final String type;
}

dynamic applyExtension(dynamic a, dynamic b) {
  unsupported();
}

abstract class JavaScriptIndexingBehavior<E> {}

/// A Dart interface may only be implemented by a native JavaScript object
/// if it is marked with this annotation.
class SupportJsExtensionMethods {
  const SupportJsExtensionMethods();
}

class Interceptor {
  const Interceptor();
}

/**
 * Utils for device detection.
 */
class Device {
  static bool _isOpera;
  static bool _isIE;
  static bool _isFirefox;
  static bool _isWebKit;
  static String _cachedCssPrefix;
  static String _cachedPropertyPrefix;

  /**
   * Gets the browser's user agent. Using this function allows tests to inject
   * the user agent.
   * Returns the user agent.
   */
  static String get userAgent => unsupported();

  /**
   * Determines if the current device is running Opera.
   */
  static bool get isOpera {
    return unsupported();
  }

  /**
   * Determines if the current device is running Internet Explorer.
   */
  static bool get isIE {
    unsupported();
  }

  /**
   * Determines if the current device is running Firefox.
   */
  static bool get isFirefox {
    unsupported();
  }

  /**
   * Determines if the current device is running WebKit.
   */
  static bool get isWebKit {
    unsupported();
  }

  /**
   * Gets the CSS property prefix for the current platform.
   */
  static String get cssPrefix {
    unsupported();
  }

  /**
   * Prefix as used for JS property names.
   */
  static String get propertyPrefix {
    unsupported();
  }

  /**
   * Checks to see if the event class is supported by the current platform.
   */
  static bool isEventTypeSupported(String eventType) {
    // Browsers throw for unsupported event names.
    unsupported();
  }
}

dynamic convertNativeToDart_SerializedScriptValue(dynamic value) =>
    unsupported();

dynamic convertDartClosureToJS(dynamic a, dynamic b) => unsupported();

dynamic convertDartToNative_SerializedScriptValue(dynamic v) => unsupported();
dynamic JS(
        [dynamic a,
        dynamic b,
        dynamic c,
        dynamic d,
        dynamic e,
        dynamic f,
        dynamic g,
        dynamic h]) =>
    unsupported();

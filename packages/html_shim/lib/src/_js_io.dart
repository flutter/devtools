// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Support for interoperating with JavaScript.
 *
 * This library provides access to JavaScript objects from Dart, allowing
 * Dart code to get and set properties, and call methods of JavaScript objects
 * and invoke JavaScript functions. The library takes care of converting
 * between Dart and JavaScript objects where possible, or providing proxies if
 * conversion isn't possible.
 *
 * This library does not yet make Dart objects usable from JavaScript, their
 * methods and proeprties are not accessible, though it does allow Dart
 * functions to be passed into and called from JavaScript.
 *
 * [JsObject] is the core type and represents a proxy of a JavaScript object.
 * JsObject gives access to the underlying JavaScript objects properties and
 * methods. `JsObject`s can be acquired by calls to JavaScript, or they can be
 * created from proxies to JavaScript constructors.
 *
 * The top-level getter [context] provides a [JsObject] that represents the
 * global object in JavaScript, usually `window`.
 *
 * The following example shows an alert dialog via a JavaScript call to the
 * global function `alert()`:
 *
 *     import 'dart:js';
 *
 *     main() => context.callMethod('alert', ['Hello from Dart!']);
 *
 * This example shows how to create a [JsObject] from a JavaScript constructor
 * and access its properties:
 *
 *     import 'dart:js';
 *
 *     main() {
 *       var object = new JsObject(context['Object']);
 *       object['greeting'] = 'Hello';
 *       object['greet'] = (name) => "${object['greeting']} $name";
 *       var message = object.callMethod('greet', ['JavaScript']);
 *       context['console'].callMethod('log', [message]);
 *     }
 *
 * ## Proxying and automatic conversion
 *
 * When setting properties on a JsObject or passing arguments to a Javascript
 * method or function, Dart objects are automatically converted or proxied to
 * JavaScript objects. When accessing JavaScript properties, or when a Dart
 * closure is invoked from JavaScript, the JavaScript objects are also
 * converted to Dart.
 *
 * Functions and closures are proxied in such a way that they are callable. A
 * Dart closure assigned to a JavaScript property is proxied by a function in
 * JavaScript. A JavaScript function accessed from Dart is proxied by a
 * [JsFunction], which has a [apply] method to invoke it.
 *
 * The following types are transferred directly and not proxied:
 *
 *   * Basic types: `null`, `bool`, `num`, `String`, `DateTime`
 *   * `TypedData`, including its subclasses like `Int32List`, but _not_
 *     `ByteBuffer`
 *   * When compiling for the web, also: `Blob`, `Event`, `ImageData`,
 *     `KeyRange`, `Node`, and `Window`.
 *
 * ## Converting collections with JsObject.jsify()
 *
 * To create a JavaScript collection from a Dart collection use the
 * [JsObject.jsify] constructor, which converts Dart [Map]s and [Iterable]s
 * into JavaScript Objects and Arrays.
 *
 * The following expression creates a new JavaScript object with the properties
 * `a` and `b` defined:
 *
 *     var jsMap = new JsObject.jsify({'a': 1, 'b': 2});
 *
 * This expression creates a JavaScript array:
 *
 *     var jsArray = new JsObject.jsify([1, 2, 3]);
 *
 * {@category Web}
 */
library dart.js;

import 'dart:collection' show HashMap, ListMixin;
import 'dart:typed_data' show TypedData;
import '_html_common_io.dart';

JsObject get context => unsupported();

/**
 * Proxies a JavaScript object to Dart.
 *
 * The properties of the JavaScript object are accessible via the `[]` and
 * `[]=` operators. Methods are callable via [callMethod].
 */
class JsObject {
  // The wrapped JS object.
  final dynamic _jsObject;

  // This shoud only be called from _wrapToDart
  JsObject._fromJs(this._jsObject) {
    unsupported();
  }

  /**
   * Constructs a new JavaScript object from [constructor] and returns a proxy
   * to it.
   */
  factory JsObject(JsFunction constructor, [List arguments]) {
    unsupported();
    return null;
  }

  /**
   * Constructs a [JsObject] that proxies a native Dart object; _for expert use
   * only_.
   *
   * Use this constructor only if you wish to get access to JavaScript
   * properties attached to a browser host object, such as a Node or Blob, that
   * is normally automatically converted into a native Dart object.
   *
   * An exception will be thrown if [object] either is `null` or has the type
   * `bool`, `num`, or `String`.
   */
  factory JsObject.fromBrowserObject(object) {
    unsupported();
    return null;
  }

  /**
   * Recursively converts a JSON-like collection of Dart objects to a
   * collection of JavaScript objects and returns a [JsObject] proxy to it.
   *
   * [object] must be a [Map] or [Iterable], the contents of which are also
   * converted. Maps and Iterables are copied to a new JavaScript object.
   * Primitives and other transferrable values are directly converted to their
   * JavaScript type, and all other objects are proxied.
   */
  factory JsObject.jsify(object) {
    unsupported();
    return null;
  }

  /**
   * Returns the value associated with [property] from the proxied JavaScript
   * object.
   *
   * The type of [property] must be either [String] or [num].
   */
  dynamic operator [](property) {
    unsupported();
    return null;
  }

  /**
   * Sets the value associated with [property] on the proxied JavaScript
   * object.
   *
   * The type of [property] must be either [String] or [num].
   */
  operator []=(property, value) {
    unsupported();
    return null;
  }

  int get hashCode => 0;

  bool operator ==(other) =>
      other is JsObject && JS('bool', '# === #', _jsObject, other._jsObject);

  /**
   * Returns `true` if the JavaScript object contains the specified property
   * either directly or though its prototype chain.
   *
   * This is the equivalent of the `in` operator in JavaScript.
   */
  bool hasProperty(property) {
    unsupported();
    return null;
  }

  /**
   * Removes [property] from the JavaScript object.
   *
   * This is the equivalent of the `delete` operator in JavaScript.
   */
  void deleteProperty(property) {
    unsupported();
    return null;
  }

  /**
   * Returns `true` if the JavaScript object has [type] in its prototype chain.
   *
   * This is the equivalent of the `instanceof` operator in JavaScript.
   */
  bool instanceof(JsFunction type) {
    unsupported();
  }

  /**
   * Returns the result of the JavaScript objects `toString` method.
   */
  String toString() {
    unsupported();
    return null;
  }

  /**
   * Calls [method] on the JavaScript object with the arguments [args] and
   * returns the result.
   *
   * The type of [method] must be either [String] or [num].
   */
  dynamic callMethod(method, [List args]) {
    unsupported();
    return null;
  }
}

/**
 * Proxies a JavaScript Function object.
 */
class JsFunction extends JsObject {
  /**
   * Returns a [JsFunction] that captures its 'this' binding and calls [f]
   * with the value of this passed as the first argument.
   */
  factory JsFunction.withThis(Function f) {
    unsupported();
    return null;
  }

  JsFunction._fromJs(jsObject) : super._fromJs(jsObject);

  /**
   * Invokes the JavaScript function with arguments [args]. If [thisArg] is
   * supplied it is the value of `this` for the invocation.
   */
  dynamic apply(List args, {thisArg}) {
    unsupported();
    return null;
  }
}

/**
 * A [List] that proxies a JavaScript array.
 */
class JsArray<E> extends JsObject with ListMixin<E> {
  /**
   * Creates a new JavaScript array.
   */
  JsArray() : super._fromJs([]);

  /**
   * Creates a new JavaScript array and initializes it to the contents of
   * [other].
   */
  JsArray.from(Iterable<E> other) : super._fromJs(unsupported());

  JsArray._fromJs(jsObject) : super._fromJs(jsObject);

  // Methods required by ListMixin

  E operator [](dynamic index) {
    unsupported();
    return null;
  }

  /*
  // This method has to be commented out because it doesn't analyze cleanly.
  void operator []=(dynamic index, [E value]) {
    unsupported();
  }*/

  int get length {
    unsupported();
    return null;
  }

  void set length(int length) {
    unsupported();
    return null;
  }

  // Methods overridden for better performance

  void add(E value) {
    unsupported();
  }

  void addAll(Iterable<E> iterable) {
    unsupported();
  }

  void insert(int index, E element) {
    unsupported();
  }

  E removeAt(int index) {
    unsupported();
  }

  E removeLast() {
    unsupported();
  }

  void removeRange(int start, int end) {
    unsupported();
  }

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    unsupported();
  }

  void sort([int compare(E a, E b)]) {
    unsupported();
  }
}

F allowInterop<F extends Function>(F f) {
  unsupported();
}

Function allowInteropCaptureThis(Function f) {
  unsupported();
}

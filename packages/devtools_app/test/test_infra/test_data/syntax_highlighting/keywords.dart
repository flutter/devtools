// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library foo;

import 'dart:async' deferred as deferredAsync show Future;
import 'dart:io' as a show File hide Directory;
export 'dart:io';

abstract class A {}

class B extends A {
  B();
  B.named();
  B.other() {}

  static late final _b = B();
  factory B.single() {
    return _b;
  }

  String get foo => '';
  set foo(String value) {}

  @override
  bool operator ==(Object other) {
    return false;
  }
}

class C<T extends B> implements A {}

mixin D on A {}

class E extends A with D {}

extension on E {}

extension EExtension on E {}

external int get externalInt;

typedef StringAlias = String;
typedef void FunctionAlias1(String a, String b);
typedef FunctionAlias2 = void Function(String a, String b);

Future<void> e() async {
  await Future.delayed(const Duration(seconds: 1));
}

void returns() {
  return;
}

Iterable<String> syncYield() sync* {
  yield '';
}

Iterable<String> syncYieldStar() sync* {
  yield* syncYield();
}

Stream<String> asyncYield() async* {
  await Future.delayed(const Duration(seconds: 1));
  yield '';
}

Stream<String> asyncYieldStar() async* {
  await Future.delayed(const Duration(seconds: 1));
  yield* asyncYield();
}

void err() {
  try {
    throw '';
  } on ArgumentError {
    rethrow;
  } catch (e) {
    print('e');
  }
}

void loops() {
  while (1 > 2) {
    if (3 > 4) {
      continue;
    } else {
      break;
    }
    return;
  }

  do {
    print('');
  } while (1 > 2);
}

void switches() {
  Object? i = 1;
  switch (i as int) {
    case 1:
      break;
    default:
      return;
  }
}

void conditions() {
  if (1 > 2) {
  } else if (3 > 4) {
  } else {}
}

void misc(int a, {required int b}) {
  assert(true);
  assert(1 == 1, 'fail');

  var a = new String.fromCharCode(1);
  const b = int.fromEnvironment('');
  final c = '';
  late final d = '';
  print(d is String);
  print(d is! String);
}

class Covariance<T> {
  void covariance(covariant List<T> items) {}
}

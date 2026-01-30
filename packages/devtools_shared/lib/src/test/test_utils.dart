// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

Future<void> waitFor(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String timeoutMessage = 'condition not satisfied',
  Duration delay = _shortDelay,
}) async {
  final end = DateTime.now().add(timeout);
  while (!end.isBefore(DateTime.now())) {
    if (await condition()) {
      return;
    }
    await Future.delayed(delay);
  }
  throw timeoutMessage;
}

Future delay({Duration duration = const Duration(milliseconds: 500)}) {
  return Future.delayed(duration);
}

Future shortDelay() {
  return delay(duration: _shortDelay);
}

const _shortDelay = Duration(milliseconds: 100);

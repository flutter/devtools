// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config_specific/logger/logger.dart';
import '../eval_on_dart_library.dart';

class ErrorLoggerObserver extends ProviderObserver {
  const ErrorLoggerObserver();

  @override
  void didAddProvider(ProviderBase provider, Object value) {
    _maybeLogError(provider, value);
  }

  @override
  void didUpdateProvider(ProviderBase provider, Object newValue) {
    _maybeLogError(provider, newValue);
  }

  void _maybeLogError(ProviderBase provider, Object value) {
    if (value is AsyncError) {
      if (value.error is SentinelException) return;
      log('Provider $provider failed with "${value.error}"', LogLevel.error);

      if (value.stackTrace != null) {
        log(value.stackTrace);
      }
    }
  }
}

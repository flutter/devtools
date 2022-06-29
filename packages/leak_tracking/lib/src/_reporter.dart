// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer';

import 'model.dart';

LeakSummary? _previous;

void reportLeaksSummary(LeakSummary leakSummary) {
  postEvent('memory_leaks_summary', leakSummary.toJson());
  if (leakSummary.equals(_previous)) return;
  _previous = leakSummary;

  // TODO(polina-c): add deep link for DevTools here.
  print(leakSummary.toMessage);
}

void reportLeaks(Leaks leaks) {
  postEvent('memory_leaks_details', leaks.toJson());
}

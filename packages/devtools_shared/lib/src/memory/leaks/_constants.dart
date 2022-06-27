// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Number of full GC cycles since start of tracking, where full GC cycle is
/// a set of GC events that, with high confidence, guarantees GC of an object
/// without retaining path.
typedef GCTime = int;

/// Distance between two [GCTime] values.
typedef GCDuration = int;

const GCDuration cyclesToDeclareLeakIfNotGCed = 2;

const Duration delayToDeclareLeakIfNotGCed = Duration(seconds: 1);

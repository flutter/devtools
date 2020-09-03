// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

void screen(
  String screenName, [
  int value = 0,
]) {}

void select(
  String screenName,
  String selectedItem, [
  int value = 0,
]) {}

void selectFrame(
  String screenName,
  String selectedItem, [
  int rasterDuration,
  int uiDuration,
]) {}

Future<void> setupDimensions() async {}

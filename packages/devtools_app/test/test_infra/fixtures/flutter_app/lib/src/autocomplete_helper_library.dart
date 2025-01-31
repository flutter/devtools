// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

export 'autocomplete_export.dart';

// This lint gets in the way of testing autocomplete.
// ignore_for_file: unused_element
int _privateFieldInOtherLibrary = 2;

int publicFieldInOtherLibrary = 3;
void _privateMethodOtherLibrary() {}
void publicMethodOtherLibrary() {}

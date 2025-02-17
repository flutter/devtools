// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// This lint gets in the way of testing.
// ignore_for_file: unused_element

void somePublicExportedMethod() {}
void _somePrivateExportedMethod() {}
int exportedField = 3;
int _privateExportedField = 10;

class ExportedClass {}

class _PrivateExportedClass {}

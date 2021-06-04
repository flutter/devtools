// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

void somePublicExportedMethod() {}
// ignore: unused_element
void _somePrivateExportedMethod() {}
int exportedField = 3;
// ignore: unused_element
int _privateExportedField = 10;

class ExportedClass {}

// ignore: unused_element
class _PrivateExportedClass {}

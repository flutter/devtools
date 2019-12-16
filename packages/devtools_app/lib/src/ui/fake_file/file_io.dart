// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

abstract class FileIO {
  void writeStringToFile(String filename, String contents);

  String readStringFromFile(String filename);

  List<String> list();

  bool deleteFile(String path);
}

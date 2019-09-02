#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on

pushd packages/devtools

rm -rf build
pub run build_runner build -o web:build --release
mv ./build/packages ./build/pack

popd

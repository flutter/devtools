#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export DART_VM_OPTIONS="-DUPDATE_GOLDENS=true"

echo "Make sure your flutter is the tip of trunk Flutter"

set -x #echo on
which flutter

pub run test --reporter expanded --tags useFlutterSdk

set +x
echo "Done updating goldens."
unset DART_VM_OPTIONS

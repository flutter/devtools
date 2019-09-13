#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

echo "Checking flutter version..."
if flutter --version | tee /dev/tty | grep -q 'channel stable'; then
  export DART_VM_OPTIONS="-DUPDATE_GOLDENS=true -DGOLDENS_SUFFIX=_stable"
  echo ""
  echo "Updating STABLE goldens because you are on the Stable flutter channel"
  echo ""
else
  export DART_VM_OPTIONS="-DUPDATE_GOLDENS=true"
  echo ""
  echo "Updating MASTER goldens"
  echo ""
fi


set -x #echo on
which flutter
cd packages/devtools_app

pub run test --reporter expanded --tags useFlutterSdk

set +x
echo "Done updating goldens."
unset DART_VM_OPTIONS

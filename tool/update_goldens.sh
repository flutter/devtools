#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

echo "Checking flutter version..."
if flutter --version | tee /dev/tty | grep -q 'channel stable'; then
  export DEVTOOLS_GOLDENS_SUFFIX="_stable"
  echo ""
  echo "Updating STABLE goldens because you are on the Stable flutter channel"
  echo ""
else
  export DEVTOOLS_GOLDENS_SUFFIX=""
  echo ""
  echo "Updating MASTER goldens"
  echo ""
fi

set -x #echo on
which flutter
cd packages/devtools_app

flutter test -j1 --update-goldens

set +x
echo "Done updating goldens."
unset DART_VM_OPTIONS

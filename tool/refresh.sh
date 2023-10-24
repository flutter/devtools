#!/bin/bash

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

echo "refresh.sh: refreshing local clone..."

bash tool/upgrade.sh

bash tool/bin/devtools_tool generate-code

echo "refresh.sh: refreshed local clone."

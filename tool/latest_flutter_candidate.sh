#!/bin/bash -x

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
RESPONSE=$(gh api --paginate /repos/flutter/flutter/branches)
CANDIDATES=$(echo "$RESPONSE" | jq '.[].name' | grep candidate)

VERSIONS=$(echo "$CANDIDATES" |  egrep -o "\d+\.\d+\-candidate\.\d+" )



LATEST_VERSION=$(echo "$VERSIONS" |  sort --version-sort | tail  -n 1 )

if [ -z ${LATEST_VERSION+x} ]; then
    echo "Unable to get Latest flutter candidate version"
    exit 1
fi

LATEST_FLUTTER_CANDIDATE="flutter-$LATEST_VERSION"

echo $LATEST_FLUTTER_CANDIDATE
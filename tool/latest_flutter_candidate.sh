#!/bin/bash

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Any subsequent commands failure will cause this script to exit immediately
set -e

if ! command -v jq &> /dev/null
then
    echo "jq could not be found. If you are on mac you can install this with `brew install jq`"
    exit 1
fi

RESPONSE=$(gh api --paginate /repos/flutter/flutter/branches)

CANDIDATES=$(echo "$RESPONSE" | jq '.[].name' | grep candidate)

VERSIONS=$(echo "$CANDIDATES" | sed -E 's/.*([0-9]+\.[0-9]+-candidate\.[0-9]+).*/\1/' )

LATEST_VERSION=$(echo "$VERSIONS" |  sort --version-sort | tail  -n 1 )

if [ -z ${LATEST_VERSION+x} ]; then
    echo "Unable to get Latest flutter candidate version"
    exit 1
fi

LATEST_FLUTTER_CANDIDATE="flutter-$LATEST_VERSION"

echo $LATEST_FLUTTER_CANDIDATE
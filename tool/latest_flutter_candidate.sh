#!/bin/bash

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Any subsequent commands failure will cause this script to exit immediately
set -e

# To determine the most recent candidate available on g3 find the largest
# tag that matches the version X.Y.Z-M.N.pre, where Z=0 and N=0.(i.e. X.Y.0-M.0.pre)
LATEST_FLUTTER_CANDIDATE=$(git ls-remote --tags --sort='-v:refname' https://flutter.googlesource.com/mirrors/flutter/ \
  | grep -E "refs/tags/[0-9]+.[0-9]+.0-[0-9]+.0.pre" \
  | cut -f2 \
  | sort --version-sort \
  | tail -n1 \
  | sed 's/^.*\(flutter.*\)$/\1/'\
  )

echo $LATEST_FLUTTER_CANDIDATE

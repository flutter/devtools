#!/bin/bash

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Any subsequent commands failure will cause this script to exit immediately
set -e

LATEST_FLUTTER_CANDIDATE=$(git ls-remote --heads --sort='-v:refname' https://flutter.googlesource.com/mirrors/flutter/ \
  | grep "refs/heads/flutter-.*-candidate" \
  | cut -f2 \
  | sort --version-sort \
  | tail -n1 \
  | sed 's/^.*\(flutter.*\)$/\1/'\
  )

echo $LATEST_FLUTTER_CANDIDATE
#!/bin/bash

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Builds a release bundle for DevTools and serve it locally. Automates 
# the steps described at: 
# https://docs.flutter.dev/deployment/web#building-the-app-for-release

# Note: This script must be executed from the top-level directory:
# ./tool/serve_release_bundle.sh

SCRIPT_PATH=$(dirname "$0")

# Build the release bundle:
$SCRIPT_PATH/build_release.sh

# Navigate to the web directory:
pushd packages/devtools_app/build/web

# Start a server to serve the web directory:
echo "-------------------------------------------"
echo "SERVING DEVTOOLS AT: http://localhost:8000/"
echo "-------------------------------------------"
if python3 --version 2>&1 | grep -q '^Python 3\.'; then
    # This is how to start a simple server with Python 3:
    python3 -m http.server 8000
elif python --version 2>&1 | grep -q '^Python 3\.'; then
    # This is how to start a simple server with Python 3 if
    # the command is aliased to "python":
    python -m http.server 8000
elif python --version 2>&1 | grep -q '^Python 2\.'; then
    # This is how to start a simple server with Python 2:
    python -m SimpleHTTPServer 8000
else 
    echo "[ERROR] Server not started. Is Python installed?"
    exit 1
fi

#!/bin/bash -e

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Contains a path to this script, relative to the directory it was called from.
RELATIVE_PATH_TO_SCRIPT="${BASH_SOURCE[0]}"

# The directory that this script is located in.
TOOL_DIR=`dirname "${RELATIVE_PATH_TO_SCRIPT}"`

# The devtools root directory is assumed to be the parent of this directory.
DEVTOOLS_DIR="${TOOL_DIR}/.."

pushd $DEVTOOLS_DIR

# new update goldens scripts
# run the docker build command
# get the image name
# run the docker run command with image name with args (test name if specified otherwise all tests) and with update goldens flag 
# may be able to use an –entrypoint flag
# we need the exit code and logs of the run. 
# now we need to get files from the docker image, and replace the existing goldens at those paths
# docker cp containerId:file/path/within/container /host/path/target


CONTAINER_NAME="goldens-container"
IMAGE_NAME="devtools:integration-test-goldens"


# TODO: use the cli to make sure docker is up and running, and if not, start it

docker build -t $IMAGE_NAME .
docker run --name $CONTAINER_NAME --rm --entrypoint "cd /home/developer/devtools/packages/devtools_app; dart run integration_test/run_tests.dart --headless" $IMAGE_NAME

SUBPATH_TO_GOLDENS_DIR=packages/devtools_app/integration_test/test_infra/goldens/ 
docker cp $CONTAINER_NAME:/home/develop/devtools/$SUBPATH_TO_GOLDENS_DIR $DEVTOOLS_DIR/$SUBPATH_TO_GOLDENS_DIR
docker container kill $CONTAINER_NAME

popd
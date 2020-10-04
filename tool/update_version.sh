#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

VERSION=$1
LAST_VERSION="$(sed -n -e 's/^.*version: //p' packages/devtools/pubspec.yaml)"

echo "The previous version was: $LAST_VERSION"

if [ -z "$VERSION" ]; then
    echo "No version specified."
    echo "Usage: tool/update_version.sh NEW_VERSION_NUMBER"
    exit 1
fi

# If you add a package that is version locked, please add it to this list.
PUBSPECS="./devtools_shared/pubspec.yaml \
./devtools_server/pubspec.yaml \
./devtools/pubspec.yaml \
./devtools_app/pubspec.yaml \
./devtools_testing/pubspec.yaml"

echo "Updating pubspec versions"

pushd packages

# We could use LAST_VERSION instead of allowing any previous version

# Update the version of all packages.
perl -pi -e "s/^(\\W*version:) [0-9.dev\-+]+/\$1 $VERSION/g" $PUBSPECS

# Update all references to package versions
perl -pi -e "s/^(\\W*devtools_shared:) \\^?[0-9\.dev\-+]+/\$1 $VERSION/g" $PUBSPECS
perl -pi -e "s/^(\\W*devtools_server:) \\^?[0-9\.dev\-+]+/\$1 $VERSION/g" $PUBSPECS
perl -pi -e "s/^(\\W*devtools:) \\^?[0-9\.dev\-+]+/\$1 $VERSION/g" $PUBSPECS
perl -pi -e "s/^(\\W*devtools_app:) \\^?[0-9\.dev\-+]+/\$1 $VERSION/g" $PUBSPECS
perl -pi -e "s/^(\\W*devtools_testing:) \\^?[0-9\.dev\-+]+/\$1 $VERSION/g" $PUBSPECS

# Update version defined in the source code in devtools_app.
perl -pi -e "s/^(\\W*const String version =) '[0-9.dev\-+]+'/\$1 '$VERSION'/g" ./devtools_app/lib/devtools.dart

popd

NEW_VERSION="$(sed -n -e 's/^.*version: //p' packages/devtools_app/pubspec.yaml)"
echo "Updated version to: $NEW_VERSION"

echo "Running pub upgrade on all packages"
tool/pub_upgrade.sh


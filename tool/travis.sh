#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

# In GitBash on Windows, we have to call dartfmt.bat and flutter.bat so we alias
# them in this script to call the correct one based on the OS.
function pub {
	if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command pub.bat "$@"
    else
        command pub "$@"
    fi
}
function dartfmt {
	if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command dartfmt.bat "$@"
    else
        command dartfmt "$@"
    fi
}
function flutter {
	if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command flutter.bat "$@"
    else
        command flutter "$@"
    fi
}

if [ -z "$USE_LOCAL_DEPENDENCIES" ]; then
    echo "Using dependencies from Pub"
else
    echo "Updating pubspecs to use local dependencies"
    perl -pi -e 's/#OVERRIDE_FOR_TESTS//' packages/devtools/pubspec.yaml
    perl -pi -e 's/#OVERRIDE_FOR_TESTS//' packages/devtools_app/pubspec.yaml
fi

# Some integration tests assume the devtools package is up to date and located
# adjacent to the devtools_app package.
pushd packages/devtools
    # We want to make sure that devtools is retrievable with regular pub.
    pub get
    # Only package:devtools and package:devtools_server should be built with
    # the pub tool. All other devtools packages and their tests now run on
    # the flutter tool, so all other invocations of pub in this script should
    # call 'flutter pub' instead of just 'pub'.
popd

# Add globally activated packages to the path.
if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    export PATH=$PATH:$APPDATA/Roaming/Pub/Cache/bin
else
    export PATH=$PATH:~/.pub-cache/bin
fi

if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    echo Installing Google Chrome Stable...
    # Install Chrome via Chocolatey while `addons: chrome` doesn't seem to work on Windows yet
    # https://travis-ci.community/t/installing-google-chrome-stable-but-i-cant-find-it-anywhere/2118
    choco install googlechrome --acceptlicense --yes --no-progress --ignore-checksums
fi

# Get Flutter.
if [ "$TRAVIS_DART_VERSION" = "stable" ]; then
    echo "Cloning stable Flutter branch"
    git clone https://github.com/flutter/flutter.git --branch stable ./flutter

    # Set the suffix so we use stable goldens.
    export DEVTOOLS_GOLDENS_SUFFIX="_stable"
else
    echo "Cloning master Flutter branch"
    git clone https://github.com/flutter/flutter.git ./flutter

    # Set the suffix so we use the master goldens
    export DEVTOOLS_GOLDENS_SUFFIX=""
fi
export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
flutter config --no-analytics
flutter doctor
# We should be using dart from ../flutter/bin/cache/dart-sdk/bin/dart.
echo "which dart: " `which dart`

pushd packages/devtools_app
echo `pwd`

# Print out the versions and ensure we can call Dart, Pub, and Flutter.
dart --version
flutter pub --version
# Put the Flutter version into a variable.
# First awk extracts "Flutter x.y.z-pre.a":
#   -F '•'         uses the bullet as field separator
#   NR==1          says only take the first record (line)
#   { print $1}    prints just the first field
# Second awk splits on space (default) and takes the second field (the version)
export FLUTTER_VERSION=$(flutter --version | awk -F '•' 'NR==1{print $1}' | awk '{print $2}')
echo "Flutter version is '$FLUTTER_VERSION'"

if [ "$BOT" = "main" ]; then

    # Provision our packages.
    flutter pub get
    flutter pub global activate webdev

    # Verify that dartfmt has been run.
    echo "Checking dartfmt..."

    if [[ $(dartfmt -n --set-exit-if-changed lib/ test/ web/) ]]; then
        echo "Failed dartfmt check: run dartfmt -w lib/ test/ web/"
        dartfmt -n --set-exit-if-changed lib/ test/ web/
        exit 1
    fi

    # Make sure the app versions are in sync.
    dart tool/version_check.dart

    # Analyze the source.
    flutter pub global activate tuneup && flutter pub global run tuneup check

    # Ensure we can build the app.
    flutter pub run build_runner build -o web:build --release

elif [ "$BOT" = "test_ddc" ]; then

    flutter pub get

    # TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
    flutter config --enable-web
    flutter build web

    # Run every test except for integration_tests.
    # The flutter tool doesn't support excluding a specific set of targets,
    # so we explicitly provide them.
    flutter test test/*.dart test/{core,fixtures,flutter,support,ui}/
    flutter test --platform chrome test/*.dart test/{core,fixtures,flutter,support,ui}/

elif [ "$BOT" = "test_dart2js" ]; then
    flutter pub get

    # TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
    flutter config --enable-web
    flutter build web

    # Run every test except for integration_tests.
    # The flutter tool doesn't support excluding a specific set of targets,
    # so we explicitly provide them.
    WEBDEV_RELEASE=true flutter test test/*.dart test/{core,fixtures,flutter,support,ui}/
    flutter test --platform chrome test/*.dart test/{core,fixtures,flutter,support,ui}/
    echo $WEBDEV_RELEASE

elif [ "$BOT" = "integration_ddc" ]; then

    # Provision our packages.
    flutter pub get
    flutter pub global activate webdev

    # We need to run integration tests with -j1 to run with no concurrency.
    flutter test -j1 test/integration_tests/

elif [ "$BOT" = "integration_dart2js" ]; then

    flutter pub get
    flutter pub global activate webdev

    # We need to run integration tests with -j1 to run with no concurrency.
    WEBDEV_RELEASE=true flutter test -j1 test/integration_tests/

elif [ "$BOT" = "packages" ]; then

    popd

    flutter pub global activate tuneup

    # Analyze packages/
    (cd packages/devtools_app; flutter pub get)
    (cd packages/devtools_server; flutter pub get)
    (cd packages/devtools_testing; flutter pub get)
    (cd packages/html_shim; flutter pub get)
    (cd packages; flutter pub global run tuneup check)

    # Analyze third_party/
    (cd third_party/packages/ansi_up; flutter pub get)
    (cd third_party/packages/mp_chart; flutter pub get)
    (cd third_party/packages/plotly_js; flutter pub get)
    (cd third_party/packages/split; flutter pub get)
    (cd third_party/packages; flutter pub global run tuneup check)

    # Analyze Dart code in tool/
    (cd tool; flutter pub global run tuneup check)

    pushd packages/devtools_app

else

    echo "unknown bot configuration"
    exit 1

fi

popd

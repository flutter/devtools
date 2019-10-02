#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

# In GitBash on Windows, we have to call pub.bat so we alias `pub` in this script to call the
# correct one based on the OS.
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

# Some integration tests assume the devtools package is up to date and located
# adjacent to the devtools_app package.
pushd packages/devtools
    pub get
popd

pushd packages/devtools_app
echo `pwd`

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

# Print out the versions and ensure we can call both Dart and Pub.
dart --version
pub --version

if [ "$BOT" = "main" ]; then

    # Provision our packages.
    pub get
    pub global activate webdev

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
    pub global activate tuneup && pub global run tuneup check

    # Ensure we can build the app.
    pub run build_runner build -o web:build --release

elif [ "$BOT" = "test_ddc" ]; then

    # Provision our packages.
    pub get
    pub global activate webdev

    pub run test -j1 --reporter expanded --exclude-tags useFlutterSdk
    pub run build_runner test -- -j1 --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "test_dart2js" ]; then

    # Provision our packages.
    pub get
    pub global activate webdev

    WEBDEV_RELEASE=true pub run --enable-asserts test -j1 --reporter expanded --exclude-tags useFlutterSdk
    pub run build_runner test -r -- -j1 --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "flutter_sdk_tests" ]; then

    # Get Flutter.
    if [ "$TRAVIS_DART_VERSION" = "stable" ]; then
        echo "Cloning stable Flutter branch"
        git clone https://github.com/flutter/flutter.git --branch stable ../flutter

        # Set the suffix so we use stable goldens.
        export DART_VM_OPTIONS="-DGOLDENS_SUFFIX=_stable"
    else
        echo "Cloning master Flutter branch"
        git clone https://github.com/flutter/flutter.git ../flutter
    fi
    cd ..
    export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
    flutter config --no-analytics
    flutter doctor

    # Put the Flutter version into a variable.
    # First awk extracts "Flutter x.y.z-pre.a":
    #   -F '•'         uses the bullet as field separator
    #   NR==1          says only take the first record (line)
    #   { print $1}    prints just the first field
    # Second awk splits on space (default) and takes the second field (the version)
    export FLUTTER_VERSION=$(flutter --version | awk -F '•' 'NR==1{print $1}' | awk '{print $2}')
    echo "Flutter version is '$FLUTTER_VERSION'"

    # We should be using dart from ../flutter/bin/cache/dart-sdk/bin/dart.
    echo "which dart: " `which dart`

    # Return to the devtools_app directory.
    cd devtools_app

    # Provision our packages using Flutter's version of Dart.
    pub get
    pub global activate webdev

    # Run tests that require the Flutter SDK.
    pub run test -j1 --reporter expanded --tags useFlutterSdk

elif [ "$BOT" = "packages" ]; then

    popd

    pub global activate tuneup

    # Analyze packages/
    (cd packages/devtools_app; pub get)
    (cd packages/devtools_server; pub get)
    (cd packages/devtools_testing; pub get)
    (cd packages/html_shim; pub get)
    (cd packages; pub global run tuneup check)

    # Analyze third_party/
    (cd third_party/packages/ansi_up; pub get)
    (cd third_party/packages/plotly_js; pub get)
    (cd third_party/packages/split; pub get)
    (cd third_party/packages; pub global run tuneup check)

    # Analyze Dart code in tool/
    (cd tool; pub global run tuneup check)

    pushd packages/devtools_app

else

    echo "unknown bot configuration"
    exit 1

fi

popd

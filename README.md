# Flutter DevTools
[![Build Status](https://travis-ci.org/flutter/devtools.svg?branch=master)](https://travis-ci.org/flutter/devtools)

Performance tools for Flutter.

## What is this?

This repo is a companion repo to the main [flutter
repo](https://github.com/flutter/flutter). It contains the source code for
a suite of Flutter performance tools.

## But there's not much here?

It's still very early in development - stay tuned.

## Issues

Please file any issues, bugs, or feature requests in the [main flutter
repo](https://github.com/flutter/flutter/issues/new).

## Trying it out

- git clone https://github.com/flutter/devtools
- cd devtools
- pub get
- pub global activate webdev

From a separate terminal:
- cd <path/to/flutter-sdk>/examples/flutter_gallery
- ensure the iOS Simulator is open (or a physical device is connected)
- flutter run

From the devtools directory:
- webdev serve

Then, open a browser window to the local url specified by webdev. After the page has loaded, append
`?port=xxx` to the url, where xxx is the port number of the service protocol port, as specified by 
the `flutter run` output.

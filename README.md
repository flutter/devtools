# Dart DevTools (preview)

[![Build Status](https://travis-ci.org/flutter/devtools.svg?branch=master)](https://travis-ci.org/flutter/devtools)

## What is this?

Dart DevTools is a suite of performance tools for Dart and Flutter. 
It’s currently in preview release, but we’re actively working on improvements and on shipping new versions.

## Getting started

For documentation on installing and trying out DevTools, please see our
[docs](https://flutter.dev/docs/development/tools/devtools/).

## Contributing and development

Contributions welcome! See our
[contributing page](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md)
for an overview of how to build and contribute to the project.

### Running the bleeding edge version

To try the latest, possibly unstable version of Dart DevTools, you can follow these steps:

1. Clone this repository: `git clone https://github.com/flutter/devtools.git`
1. Go to the newly created directory: `cd devtools`
1. Go to the `devtools_app` project: `cd packages/devtools_app`
1. Run DevTools: `flutter run -d chrome --release`

You will need a recent version of Flutter (`beta` as of March 2020) and you'll need to have the web target enabled (`flutter config --enable-web`). If you want to run Dart DevTools as a Mac app, you can run `flutter run -d macos` (for which you need the macOS target enabled via `flutter config --enable-macos-desktop`, and a `dev` version of Flutter).

## Terms and Privacy

By using Dart DevTools, you agree to the [Google Terms of Service](https://policies.google.com/terms).

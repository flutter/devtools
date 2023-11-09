# Build DevTools

This page describes the fastest way to build DevTools with the goal to use it. Do not mix this setup with development environment. If you want to make code changes, follow [contributing guidance](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md).

You may want to build DevTools to:

1. Try experimental features

2. Run desktop version, instead of Web version, to get get rid of browser memory limit. For example,
to be able to analyze heap snapshots of more complicated applications.

These steps were tested for Mac and may require adjustments for other platforms. Contributions
that make the steps more platform agnostic are welcome.

## Prerequisites

1. [Configure](https://docs.flutter.dev/get-started/install) Dart or Flutter.

## Setup DevTools (first time only)

1. In your terminal `cd` to a folder where you want to clone devtools, and that does not have subfolder `devtools` yet.

2. Clone the repo and update the Flutter SDK that DevTools will be built with:

```bash
git clone https://github.com/flutter/devtools.git

bash devtools/tool/update_flutter_sdk.sh
cd devtools
```

## Or refresh DevTools

If you have already configured the DevTools environment and need to refresh to get the latest DevTools code, follow these instructions:

1. `cd` to the `devtools` directory created in the [Setup and start](#setup-and-start) section.

2. Refresh DevTools (it will delete all your local changes!):

```bash
git checkout master
git reset --hard origin/master

bash tool/update_flutter_sdk.sh
devtools_tool pub-get --only-main --upgrade
```

If some steps failed, remove the directory and redo to [Setup](#setup).

## Start DevTools and connect to an app

1. From the main devtools directory, run `cd packages/devtools_app``

2. Start DevTools

- On Chrome: `../../tool/flutter-sdk/bin/flutter run --release -d chrome`
- On Mac: `../../tool/flutter-sdk/bin/flutter run --release -d macos`
- On Windows: `../../tool/flutter-sdk/bin/flutter run --release -d windows`

Add `--dart-define=enable_experiments=true` to enable experimental features.

3. Paste the URL of your application
(for example [Gallery](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-to-application))
to the connection textbox.

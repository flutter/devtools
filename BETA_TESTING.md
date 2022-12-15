# Beta testing

This page describes the fastest way to test the latest version of DevTools with all experemental features enabled. Do not mix this setup with development environment.

If you want to make code changes, follow [contributing guidance](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md).

The steps were tested for Mac. They may require adjustments for other platforms.

## Prerequisites

1. [Configure](https://docs.flutter.dev/get-started/install) Dart or Flutter.

## Setup and start

1. In your terminal `cd` to a folder where you want to clone devtools, and that does not have subfolder `devtools` yet.

2. Clone the repo, get needed Flutter version to local folder and start DevTools:

```bash
git clone https://github.com/flutter/devtools.git

./devtools/tool/update_flutter_sdk.sh

cd devtools/packages/devtools_app
../../tool/flutter-sdk/bin/flutter run -d chrome --dart-define=enable_experiments=true
```

3. Paste the URL of your application (for example [Gallery](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-to-application)) to the connection textbox.

## Refresh and start

1. `cd` to the `devtools` directory created in the [Setup and start](#setup-and-start) section.

2. Refresh and run DevTools (it will delete all your local changes!):

```bash
git checkout master
git reset --hard origin/master

./tool/update_flutter_sdk.sh
cd packages/devtools_app
../../tool/flutter-sdk/bin/flutter pub upgrade

../../tool/flutter-sdk/bin/flutter run -d chrome --dart-define=enable_experiments=true
```

3. Paste the URL of your application (for example [Gallery](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-to-application)) to the connection textbox.
